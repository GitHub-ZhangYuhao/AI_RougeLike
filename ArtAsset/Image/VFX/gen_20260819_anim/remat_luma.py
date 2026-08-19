"""Luminance-based alpha matting for fire-on-black VFX sequences.

BiRefNet (salient-object segmentation) erodes diffuse fire bursts; for
emissive effects on a flat dark background, luminance-derived alpha keeps
the full burst: alpha = (max_channel - black_point) ^ gamma, RGB stored
straight (unmultiplied with the linear alpha).
"""
from __future__ import annotations

import argparse
import csv
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage


def estimate_black(rgb: np.ndarray, border_width: int = 24) -> float:
    """Flat dark background luminance from the frame border."""
    h, w = rgb.shape[:2]
    b = max(1, min(border_width, h // 4, w // 4))
    border = np.concatenate(
        [
            rgb[:b].reshape(-1, 3),
            rgb[-b:].reshape(-1, 3),
            rgb[b:-b, :b].reshape(-1, 3),
            rgb[b:-b, -b:].reshape(-1, 3),
        ]
    )
    return float(np.median(border.max(axis=1)))


def bleed_fill(rgb: np.ndarray, alpha: np.ndarray, bleed_radius: int) -> np.ndarray:
    """Pad transparent RGB from the nearest visible pixel for texture filtering."""
    result = rgb.copy()
    known = alpha >= 16
    result[~known] = 0
    if np.any(known) and np.any(~known) and bleed_radius > 0:
        distance, indices = ndimage.distance_transform_edt(~known, return_indices=True)
        fill = (~known) & (distance <= bleed_radius)
        nearest = result[indices[0], indices[1]]
        result[fill] = nearest[fill]
    return np.clip(np.rint(result), 0, 255).astype(np.uint8)


def main() -> None:
    parser = argparse.ArgumentParser(description="Luminance alpha matting for fire-on-black sequences")
    parser.add_argument("--input", required=True, help="Raw RGB PNG sequence directory")
    parser.add_argument("--output", required=True, help="Output RGBA PNG directory")
    parser.add_argument("--gamma", type=float, default=0.8, help="Alpha boost gamma (<1 thickens glow)")
    parser.add_argument("--noise-floor", type=float, default=0.02, help="Linear alpha below this -> 0")
    parser.add_argument("--bleed-radius", type=int, default=24)
    args = parser.parse_args()

    input_dir = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(input_dir.glob("frame_*.png"))
    if not files:
        raise SystemExit(f"No frame_*.png files found in {input_dir}")

    stats: list[dict[str, object]] = []
    total_start = time.perf_counter()
    for index, src in enumerate(files, 1):
        start = time.perf_counter()
        rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)

        black = estimate_black(rgb)
        maxc = rgb.max(axis=2)
        a_lin = np.clip((maxc - black) / (255.0 - black), 0.0, 1.0)
        a_lin[a_lin < args.noise_floor] = 0.0

        alpha_f = np.power(a_lin, args.gamma)
        alpha = np.rint(alpha_f * 255.0)
        alpha[alpha <= 2] = 0
        alpha[alpha >= 253] = 255
        alpha_u8 = alpha.astype(np.uint8)

        # Straight (unmultiplied) RGB using the linear alpha, clamped.
        a_um = np.maximum(a_lin, 0.10)[..., None]
        straight = np.clip(rgb / a_um, 0.0, 255.0)
        straight_u8 = bleed_fill(straight, alpha_u8, args.bleed_radius)

        rgba = np.dstack([straight_u8, alpha_u8])
        Image.fromarray(rgba, mode="RGBA").save(output_dir / src.name, compress_level=3)

        elapsed = time.perf_counter() - start
        visible = float(np.mean(alpha_u8 >= 8))
        opaque = float(np.mean(alpha_u8 >= 247))
        soft = float(np.mean((alpha_u8 > 8) & (alpha_u8 < 247)))
        stats.append(
            {
                "frame": src.name,
                "visible_fraction": visible,
                "opaque_fraction": opaque,
                "soft_edge_fraction": soft,
                "alpha_mean": float(alpha_u8.mean()),
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

    print(f"Completed {len(files)} frames in {time.perf_counter() - total_start:.1f}s")
    print(f"Output: {output_dir.resolve()}")


if __name__ == "__main__":
    main()
