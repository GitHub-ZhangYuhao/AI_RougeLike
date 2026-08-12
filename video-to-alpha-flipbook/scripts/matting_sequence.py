from __future__ import annotations

import argparse
import csv
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from rembg import new_session, remove
from scipy import ndimage


def estimate_background(rgb: np.ndarray, alpha: np.ndarray, border_width: int = 24) -> np.ndarray:
    """Estimate a flat background color from transparent pixels around the frame border."""
    h, w = alpha.shape
    b = max(1, min(border_width, h // 4, w // 4))
    border_rgb = np.concatenate(
        [
            rgb[:b].reshape(-1, 3),
            rgb[-b:].reshape(-1, 3),
            rgb[b:-b, :b].reshape(-1, 3),
            rgb[b:-b, -b:].reshape(-1, 3),
        ]
    )
    border_alpha = np.concatenate(
        [
            alpha[:b].reshape(-1),
            alpha[-b:].reshape(-1),
            alpha[b:-b, :b].reshape(-1),
            alpha[b:-b, -b:].reshape(-1),
        ]
    )
    candidates = border_rgb[border_alpha <= 8]
    if len(candidates) < 128:
        candidates = border_rgb
    return np.median(candidates, axis=0).astype(np.float32)


def decontaminate_and_bleed(
    rgb: np.ndarray,
    alpha: np.ndarray,
    bleed_radius: int = 24,
) -> np.ndarray:
    """Remove flat-background color spill on soft edges and pad transparent RGB for texture filtering."""
    source = rgb.astype(np.float32)
    a = alpha.astype(np.float32) / 255.0
    background = estimate_background(rgb, alpha)

    result = source.copy()
    edge = (a >= 0.05) & (a < 0.98)
    if np.any(edge):
        recovered = (source - (1.0 - a[..., None]) * background[None, None, :]) / np.maximum(
            a[..., None], 0.05
        )
        result[edge] = np.clip(recovered[edge], 0.0, 255.0)

    # Pixels with tiny alpha are unreliable. Their RGB is filled from the nearest visible pixel.
    known = alpha >= 16
    result[~known] = 0
    if np.any(known) and np.any(~known) and bleed_radius > 0:
        distance, indices = ndimage.distance_transform_edt(~known, return_indices=True)
        fill = (~known) & (distance <= bleed_radius)
        nearest = result[indices[0], indices[1]]
        result[fill] = nearest[fill]

    return np.clip(np.rint(result), 0, 255).astype(np.uint8)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert an RGB PNG sequence into an RGBA foreground sequence.")
    parser.add_argument("--input", default="frames_raw", help="Input PNG sequence directory")
    parser.add_argument("--output", default="frames_alpha", help="Output RGBA PNG directory")
    parser.add_argument("--model", default="birefnet-general-lite", help="rembg model name")
    parser.add_argument("--provider", default="DmlExecutionProvider", help="ONNX Runtime provider")
    parser.add_argument("--bleed-radius", type=int, default=24, help="Transparent RGB padding radius")
    args = parser.parse_args()

    input_dir = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(input_dir.glob("frame_*.png"))
    if not files:
        raise SystemExit(f"No frame_*.png files found in {input_dir}")

    providers = [args.provider]
    if args.provider != "CPUExecutionProvider":
        providers.append("CPUExecutionProvider")

    print(f"Loading model: {args.model}", flush=True)
    print(f"Providers: {providers}", flush=True)
    session = new_session(args.model, providers=providers)

    stats: list[dict[str, object]] = []
    total_start = time.perf_counter()
    for index, src in enumerate(files, 1):
        start = time.perf_counter()
        rgb_image = Image.open(src).convert("RGB")
        rgb = np.asarray(rgb_image)

        mask_image = remove(rgb_image, session=session, only_mask=True, post_process_mask=False)
        alpha = np.asarray(mask_image.convert("L"), dtype=np.uint8).copy()
        alpha[alpha <= 2] = 0
        alpha[alpha >= 253] = 255

        cleaned_rgb = decontaminate_and_bleed(rgb, alpha, args.bleed_radius)
        rgba = np.dstack([cleaned_rgb, alpha])
        dst = output_dir / src.name
        Image.fromarray(rgba, mode="RGBA").save(dst, compress_level=3)

        elapsed = time.perf_counter() - start
        visible = float(np.mean(alpha >= 8))
        opaque = float(np.mean(alpha >= 247))
        soft = float(np.mean((alpha > 8) & (alpha < 247)))
        stats.append(
            {
                "frame": src.name,
                "visible_fraction": visible,
                "opaque_fraction": opaque,
                "soft_edge_fraction": soft,
                "alpha_mean": float(alpha.mean()),
                "seconds": elapsed,
            }
        )
        print(
            f"[{index:03d}/{len(files):03d}] {src.name} "
            f"visible={visible:.2%} soft={soft:.2%} time={elapsed:.2f}s",
            flush=True,
        )

    stats_path = output_dir / "matting_stats.csv"
    with stats_path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=list(stats[0].keys()))
        writer.writeheader()
        writer.writerows(stats)

    print(f"Completed {len(files)} frames in {time.perf_counter() - total_start:.1f}s", flush=True)
    print(f"Output: {output_dir.resolve()}", flush=True)
    print(f"Statistics: {stats_path.resolve()}", flush=True)


if __name__ == "__main__":
    main()
