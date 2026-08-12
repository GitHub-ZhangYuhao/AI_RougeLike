from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser(description="Create checkerboard and playback previews for a sprite sheet.")
    parser.add_argument("atlas", help="RGBA sprite sheet PNG")
    parser.add_argument("--preview-size", type=int, default=512)
    parser.add_argument("--background", default="36,179,90", help="RGB background for playback preview")
    args = parser.parse_args()

    atlas_path = Path(args.atlas)
    metadata_path = atlas_path.with_suffix(".json")
    if not metadata_path.exists():
        raise SystemExit(f"Missing metadata: {metadata_path}")

    meta = json.loads(metadata_path.read_text(encoding="utf-8"))
    rgba = np.asarray(Image.open(atlas_path).convert("RGBA"))
    if rgba.shape[1] != meta["atlas_width"] or rgba.shape[0] != meta["atlas_height"]:
        raise SystemExit("Atlas dimensions do not match metadata")

    # Static checkerboard preview.
    h, w = rgba.shape[:2]
    yy, xx = np.indices((h, w))
    checker = ((xx // 32 + yy // 32) % 2)[..., None]
    bg = np.repeat(np.where(checker, 190, 125).astype(np.uint8), 3, axis=2)
    alpha = rgba[..., 3:4].astype(np.float32) / 255.0
    composite = np.clip(rgba[..., :3] * alpha + bg * (1.0 - alpha), 0, 255).astype(np.uint8)
    checker_image = Image.fromarray(composite, "RGB")
    draw = ImageDraw.Draw(checker_image)

    x_edges = sorted(
        set([0, w] + [int(f["pixel_min_x"]) for f in meta["frames"]] + [int(f["pixel_max_x"]) for f in meta["frames"]])
    )
    y_edges = sorted(
        set([0, h] + [int(f["pixel_min_y"]) for f in meta["frames"]] + [int(f["pixel_max_y"]) for f in meta["frames"]])
    )
    for x in x_edges:
        draw.line([(x, 0), (x, h - 1)], fill=(255, 80, 80), width=2)
    for y in y_edges:
        draw.line([(0, y), (w - 1, y)], fill=(255, 80, 80), width=2)
    for frame in meta["frames"]:
        x, y, slot = int(frame["pixel_min_x"]), int(frame["pixel_min_y"]), int(frame["slot"])
        draw.rectangle((x + 5, y + 5, x + 57, y + 29), fill=(0, 0, 0))
        draw.text((x + 9, y + 9), f"{slot:02d}", fill=(255, 255, 255))

    checker_path = atlas_path.with_name(atlas_path.stem + "_checker_preview.jpg")
    checker_image.save(checker_path, quality=93)

    # Playback preview reconstructed from the actual atlas cells.
    preview_size = args.preview_size
    fps = float(meta["sampled_playback_fps"])
    frame_count = int(meta["sampled_frame_count"])
    background = np.array([int(v.strip()) for v in args.background.split(",")], dtype=np.float32)
    if background.shape != (3,):
        raise SystemExit("--background must be R,G,B")

    video_path = atlas_path.with_name(atlas_path.stem + "_playback_preview.mp4")
    command = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{preview_size}x{preview_size}", "-r", f"{fps:.9f}", "-i", "-",
        "-frames:v", str(frame_count), "-c:v", "libx264", "-preset", "medium",
        "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video_path),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    for frame in meta["frames"]:
        x0, y0 = int(frame["pixel_min_x"]), int(frame["pixel_min_y"])
        x1, y1 = int(frame["pixel_max_x"]), int(frame["pixel_max_y"])
        tile = rgba[y0:y1, x0:x1]
        tile = cv2.resize(tile, (preview_size, preview_size), interpolation=cv2.INTER_CUBIC)
        a = tile[..., 3:4].astype(np.float32) / 255.0
        bg_frame = np.empty((preview_size, preview_size, 3), dtype=np.float32)
        bg_frame[:] = background
        rgb = np.clip(tile[..., :3] * a + bg_frame * (1.0 - a), 0, 255).astype(np.uint8)
        process.stdin.write(rgb.tobytes())
    process.stdin.close()
    return_code = process.wait()
    if return_code:
        raise SystemExit(return_code)

    print(f"Checker preview: {checker_path.resolve()}")
    print(f"Playback preview: {video_path.resolve()}")


if __name__ == "__main__":
    main()
