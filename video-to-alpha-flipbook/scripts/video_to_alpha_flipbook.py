from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime
from fractions import Fraction
from pathlib import Path


def run(command: list[str]) -> None:
    print("+", subprocess.list2cmdline(command), flush=True)
    subprocess.run(command, check=True)


def probe_video(video: Path) -> dict:
    result = subprocess.run(
        [
            "ffprobe", "-v", "error", "-show_entries",
            "format=duration,size,bit_rate:stream=index,codec_name,codec_type,width,height,r_frame_rate,avg_frame_rate,pix_fmt,nb_frames",
            "-of", "json", str(video),
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return json.loads(result.stdout)


def video_fps(probe: dict) -> float:
    streams = [s for s in probe.get("streams", []) if s.get("codec_type") == "video"]
    if not streams:
        raise SystemExit("Input contains no video stream")
    value = streams[0].get("avg_frame_rate") or streams[0].get("r_frame_rate") or "25/1"
    try:
        fps = float(Fraction(value))
    except (ValueError, ZeroDivisionError):
        fps = 25.0
    return fps if fps > 0 else 25.0


def choose_provider(requested: str) -> str:
    import onnxruntime as ort

    available = ort.get_available_providers()
    if requested != "auto":
        if requested not in available:
            raise SystemExit(f"Requested provider {requested} is unavailable. Available: {available}")
        return requested
    for candidate in ("DmlExecutionProvider", "CUDAExecutionProvider", "CPUExecutionProvider"):
        if candidate in available:
            return candidate
    raise SystemExit(f"No usable ONNX Runtime provider. Available: {available}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert a video into raw PNG frames, alpha PNG frames, and a sampled RGBA flipbook atlas."
    )
    parser.add_argument("input_video")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--grid", type=int, default=6, help="Square atlas grid, e.g. 5, 6, or 8")
    parser.add_argument("--atlas-size", type=int, default=2048)
    parser.add_argument("--gutter", type=int, default=8)
    parser.add_argument("--content-max", type=int, default=0, help="0 chooses the largest safe value")
    parser.add_argument("--model", default="birefnet-general-lite")
    parser.add_argument("--provider", default="auto")
    parser.add_argument("--skip-matting", action="store_true")
    parser.add_argument("--skip-atlas", action="store_true")
    parser.add_argument("--no-preview", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        raise SystemExit("ffmpeg and ffprobe must be available on PATH")
    if args.grid < 1:
        raise SystemExit("--grid must be at least 1")

    video = Path(args.input_video).expanduser().resolve()
    if not video.is_file():
        raise SystemExit(f"Input video not found: {video}")

    output_dir = (
        Path(args.output_dir).expanduser().resolve()
        if args.output_dir
        else video.with_name(f"{video.stem}_flipbook_{args.grid}x{args.grid}")
    )
    if output_dir.exists() and any(output_dir.iterdir()):
        if not args.force:
            raise SystemExit(f"Output directory is not empty: {output_dir}. Use --force to replace it.")
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    scripts_dir = Path(__file__).resolve().parent
    raw_dir = output_dir / "frames_raw"
    alpha_dir = output_dir / "frames_alpha"
    raw_dir.mkdir()

    probe = probe_video(video)
    fps = video_fps(probe)
    print(f"Input FPS: {fps:.6f}", flush=True)

    run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(video),
            "-map", "0:v:0", "-fps_mode", "passthrough", "-start_number", "1",
            "-compression_level", "3", str(raw_dir / "frame_%04d.png"),
        ]
    )
    raw_files = sorted(raw_dir.glob("frame_*.png"))
    if not raw_files:
        raise SystemExit("No frames were extracted")

    provider = None
    atlas_input = raw_dir
    if not args.skip_matting:
        provider = choose_provider(args.provider)
        print(f"Matting provider: {provider}", flush=True)
        run(
            [
                sys.executable, str(scripts_dir / "matting_sequence.py"),
                "--input", str(raw_dir), "--output", str(alpha_dir),
                "--model", args.model, "--provider", provider, "--bleed-radius", "24",
            ]
        )
        alpha_files = sorted(alpha_dir.glob("frame_*.png"))
        if len(alpha_files) != len(raw_files):
            raise SystemExit(f"Alpha frame count mismatch: raw={len(raw_files)}, alpha={len(alpha_files)}")
        atlas_input = alpha_dir

    atlas_path: Path | None = None
    metadata_path: Path | None = None
    if not args.skip_atlas:
        samples = args.grid * args.grid
        if samples > len(raw_files):
            raise SystemExit(
                f"Grid {args.grid}x{args.grid} needs {samples} source frames, but only {len(raw_files)} were extracted"
            )
        content_max = args.content_max or (args.atlas_size // args.grid - 2 * args.gutter)
        if content_max < 1:
            raise SystemExit("Atlas cells are too small for the selected gutter")
        atlas_path = output_dir / f"sprite_sheet_{args.grid}x{args.grid}_{samples}f_{args.atlas_size}.png"
        run(
            [
                sys.executable, str(scripts_dir / "build_sprite_sheet.py"),
                "--input", str(atlas_input), "--output", str(atlas_path),
                "--samples", str(samples), "--columns", str(args.grid),
                "--atlas-size", str(args.atlas_size), "--content-max", str(content_max),
                "--gutter", str(args.gutter), "--source-fps", f"{fps:.9f}",
            ]
        )
        metadata_path = atlas_path.with_suffix(".json")
        if not args.no_preview:
            run([sys.executable, str(scripts_dir / "preview_sprite_sheet.py"), str(atlas_path)])

    video_stream = next(s for s in probe["streams"] if s.get("codec_type") == "video")
    report_lines = [
        "# Video to Alpha Flipbook Report",
        "",
        f"- Generated: {datetime.now().isoformat(timespec='seconds')}",
        f"- Input: `{video}`",
        f"- Resolution: {video_stream.get('width')} × {video_stream.get('height')}",
        f"- Source FPS: {fps:.6f}",
        f"- Extracted frames: {len(raw_files)}",
        f"- Alpha matting: {'disabled' if args.skip_matting else args.model}",
        f"- ONNX provider: {provider or 'not used'}",
        f"- Raw frames: `{raw_dir}`",
    ]
    if not args.skip_matting:
        report_lines.append(f"- Alpha frames: `{alpha_dir}`")
    if atlas_path and metadata_path:
        meta = json.loads(metadata_path.read_text(encoding="utf-8"))
        report_lines.extend(
            [
                f"- Atlas: `{atlas_path}`",
                f"- Grid: {meta['columns']} × {meta['rows']}",
                f"- Sampled frames: {meta['sampled_frame_count']}",
                f"- Atlas size: {meta['atlas_width']} × {meta['atlas_height']}",
                f"- Resized frame: {meta['resized_frame_width']} × {meta['resized_frame_height']}",
                f"- Playback FPS: {meta['sampled_playback_fps']:.6f}",
            ]
        )
    report_path = output_dir / "PROCESS_REPORT.md"
    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

    manifest = {
        "input_video": str(video),
        "output_directory": str(output_dir),
        "probe": probe,
        "source_fps": fps,
        "extracted_frame_count": len(raw_files),
        "matting_model": None if args.skip_matting else args.model,
        "onnx_provider": provider,
        "atlas": str(atlas_path) if atlas_path else None,
        "report": str(report_path),
    }
    (output_dir / "pipeline_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print("\nCompleted", flush=True)
    print(f"Output directory: {output_dir}", flush=True)
    print(f"Report: {report_path}", flush=True)


if __name__ == "__main__":
    main()
