from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def evenly_spaced_indices(total: int, count: int) -> list[int]:
    if count < 1 or count > total:
        raise ValueError(f"sample count must be between 1 and {total}")
    indices = np.rint(np.linspace(0, total - 1, count)).astype(int).tolist()
    if len(set(indices)) != count:
        raise ValueError("sampling produced duplicate frame indices")
    return indices


def grid_edges(count: int, fixed_cell: int, exact_atlas: int | None) -> np.ndarray:
    if exact_atlas is None:
        return np.arange(count + 1, dtype=int) * fixed_cell
    # Rounded normalized boundaries keep an exact atlas size even when the size is
    # not evenly divisible by the number of rows/columns (for example 2048 / 6).
    return np.rint(np.linspace(0, exact_atlas, count + 1)).astype(int)


def resize_rgba_with_gutter(
    rgba: np.ndarray,
    cell_width: int,
    cell_height: int,
    content_max: int,
    gutter: int,
) -> tuple[np.ndarray, tuple[int, int], tuple[int, int]]:
    h, w = rgba.shape[:2]
    scale = min(content_max / w, content_max / h)
    out_w = max(1, int(round(w * scale)))
    out_h = max(1, int(round(h * scale)))

    rgb = cv2.resize(rgba[..., :3], (out_w, out_h), interpolation=cv2.INTER_AREA)
    alpha = cv2.resize(rgba[..., 3], (out_w, out_h), interpolation=cv2.INTER_AREA)

    # Extend RGB into a transparent gutter to prevent neighboring-frame color bleeding
    # during bilinear filtering and mipmap generation. Alpha in the gutter stays zero.
    padded_rgb = cv2.copyMakeBorder(rgb, gutter, gutter, gutter, gutter, cv2.BORDER_REPLICATE)
    padded_alpha = cv2.copyMakeBorder(
        alpha, gutter, gutter, gutter, gutter, cv2.BORDER_CONSTANT, value=0
    )
    padded = np.dstack([padded_rgb, padded_alpha])

    ph, pw = padded.shape[:2]
    if pw > cell_width or ph > cell_height:
        raise ValueError(
            f"padded frame {pw}x{ph} exceeds cell {cell_width}x{cell_height}; "
            "reduce content_max or gutter"
        )

    tile = np.zeros((cell_height, cell_width, 4), dtype=np.uint8)
    x = (cell_width - pw) // 2
    y = (cell_height - ph) // 2
    tile[y : y + ph, x : x + pw] = padded
    return tile, (out_w, out_h), (x + gutter, y + gutter)


def main() -> None:
    parser = argparse.ArgumentParser(description="Uniformly sample an RGBA sequence into a sprite sheet.")
    parser.add_argument("--input", default="frames_alpha")
    parser.add_argument("--output", default="sprite_sheet_8x8_64f_2048.png")
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--columns", type=int, default=8)
    parser.add_argument("--cell-size", type=int, default=256)
    parser.add_argument(
        "--atlas-size",
        type=int,
        default=None,
        help="Exact square atlas size. Cells may differ by one pixel when not divisible by the grid.",
    )
    parser.add_argument("--content-max", type=int, default=240)
    parser.add_argument("--gutter", type=int, default=8)
    parser.add_argument("--source-fps", type=float, default=25.0)
    args = parser.parse_args()

    files = sorted(Path(args.input).glob("frame_*.png"))
    if not files:
        raise SystemExit(f"No frame_*.png files found in {args.input}")

    rows = int(np.ceil(args.samples / args.columns))
    indices = evenly_spaced_indices(len(files), args.samples)
    x_edges = grid_edges(args.columns, args.cell_size, args.atlas_size)
    y_edges = grid_edges(rows, args.cell_size, args.atlas_size)
    atlas_width = int(x_edges[-1])
    atlas_height = int(y_edges[-1])
    atlas = np.zeros((atlas_height, atlas_width, 4), dtype=np.uint8)

    min_cell_width = int(np.diff(x_edges).min())
    max_cell_width = int(np.diff(x_edges).max())
    min_cell_height = int(np.diff(y_edges).min())
    max_cell_height = int(np.diff(y_edges).max())
    if args.content_max + 2 * args.gutter > min(min_cell_width, min_cell_height):
        raise SystemExit(
            "content-max + 2*gutter exceeds the smallest grid cell: "
            f"{args.content_max} + {2 * args.gutter} > {min(min_cell_width, min_cell_height)}"
        )

    mapping: list[dict[str, object]] = []
    resized_sizes: set[tuple[int, int]] = set()
    content_offsets: set[tuple[int, int]] = set()

    for slot, source_index in enumerate(indices):
        source = files[source_index]
        row = slot // args.columns
        column = slot % args.columns
        x0, x1 = int(x_edges[column]), int(x_edges[column + 1])
        y0, y1 = int(y_edges[row]), int(y_edges[row + 1])
        cell_width, cell_height = x1 - x0, y1 - y0

        rgba = np.asarray(Image.open(source).convert("RGBA"))
        tile, current_size, current_offset = resize_rgba_with_gutter(
            rgba, cell_width, cell_height, args.content_max, args.gutter
        )
        resized_sizes.add(current_size)
        content_offsets.add(current_offset)
        atlas[y0:y1, x0:x1] = tile

        mapping.append(
            {
                "slot": slot,
                "row": row,
                "column": column,
                "source_file": source.name,
                "source_frame_number": source_index + 1,
                "source_time_seconds": round(source_index / args.source_fps, 6),
                "pixel_min_x": x0,
                "pixel_min_y": y0,
                "pixel_max_x": x1,
                "pixel_max_y": y1,
                "cell_width": cell_width,
                "cell_height": cell_height,
                "uv_min_x": column / args.columns,
                "uv_min_y": row / rows,
                "uv_max_x": (column + 1) / args.columns,
                "uv_max_y": (row + 1) / rows,
            }
        )

    output = Path(args.output)
    Image.fromarray(atlas, mode="RGBA").save(output, compress_level=3)

    duration_seconds = len(files) / args.source_fps
    playback_fps = args.samples / duration_seconds
    resized_size = sorted(resized_sizes)[0]
    metadata = {
        "source_directory": str(Path(args.input)),
        "source_frame_count": len(files),
        "source_fps": args.source_fps,
        "source_duration_seconds": duration_seconds,
        "sampled_frame_count": args.samples,
        "sampled_playback_fps": playback_fps,
        "sampling": "uniform_including_first_and_last_frame",
        "columns": args.columns,
        "rows": rows,
        "cell_width_min": min_cell_width,
        "cell_width_max": max_cell_width,
        "cell_height_min": min_cell_height,
        "cell_height_max": max_cell_height,
        "atlas_width": atlas_width,
        "atlas_height": atlas_height,
        "resized_frame_width": resized_size[0],
        "resized_frame_height": resized_size[1],
        "content_max_edge": args.content_max,
        "transparent_gutter": args.gutter,
        "content_offsets_observed": sorted([list(v) for v in content_offsets]),
        "pixel_format": "RGBA8 straight alpha",
        "frames": mapping,
    }

    json_path = output.with_suffix(".json")
    json_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    csv_path = output.with_suffix(".csv")
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=list(mapping[0].keys()))
        writer.writeheader()
        writer.writerows(mapping)

    print(f"Source frames: {len(files)}")
    print(f"Sampled frames: {args.samples}")
    print(f"Grid: {args.columns}x{rows}")
    print(f"Resized frame: {resized_size[0]}x{resized_size[1]}")
    print(
        f"Cell range: {min_cell_width}-{max_cell_width} x "
        f"{min_cell_height}-{max_cell_height}, gutter: {args.gutter}px"
    )
    print(f"Atlas: {atlas_width}x{atlas_height}")
    print(f"Playback FPS for original duration: {playback_fps:.6f}")
    print(f"PNG: {output.resolve()}")
    print(f"JSON: {json_path.resolve()}")
    print(f"CSV: {csv_path.resolve()}")


if __name__ == "__main__":
    main()
