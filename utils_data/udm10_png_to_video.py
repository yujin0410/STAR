"""Convert UDM10-style per-sequence PNG frames into MP4 files for STAR inference.

UDM10 is shipped as:
    <src>/<sequence_name>/<frame_idx>.png

This script walks every sub-directory under ``--src`` that contains PNG frames
and encodes the frames into a single ``<sequence_name>.mp4`` under ``--dst``
using ffmpeg. The resulting layout is directly consumable by
``video_super_resolution/scripts/inference_sr.sh``.

Example:
    python utils_data/udm10_png_to_video.py \\
        --src /mnt/HDD_raid1/yjcho/data/UDM10/BIx4 \\
        --dst /mnt/HDD_raid1/yjcho/data/UDM10/LQ-Video \\
        --fps 25
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


def find_sequences(src: Path):
    """Return a list of (name, frames_dir) for every subdir with PNG frames."""
    sequences = []
    for entry in sorted(src.iterdir()):
        if not entry.is_dir():
            continue
        if any(entry.glob("*.png")) or any(entry.glob("*.PNG")):
            sequences.append((entry.name, entry))
    return sequences


def detect_pattern(frames_dir: Path):
    """Detect an ffmpeg image2 pattern (e.g. ``%08d.png``) and its start index."""
    pngs = sorted(p.name for p in frames_dir.iterdir() if p.suffix.lower() == ".png")
    if not pngs:
        return None, 0, 0
    m = re.match(r"^(\D*)(\d+)(\.[Pp][Nn][Gg])$", pngs[0])
    if not m:
        raise RuntimeError(
            f"Unrecognised PNG filename format in {frames_dir}: {pngs[0]}"
        )
    prefix, num, ext = m.groups()
    width = len(num)
    start = int(num)
    pattern = f"{prefix}%0{width}d{ext}"
    return pattern, start, len(pngs)


def convert(frames_dir: Path, out_path: Path, fps: int, crf: int) -> None:
    pattern, start, n_frames = detect_pattern(frames_dir)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # ``-vf format=rgb24`` forces ffmpeg to decode every PNG to 8-bit RGB
    # BEFORE the yuv420p conversion. Without it, 16-bit PNGs (which some
    # UDM10 distributions ship) or RGBA PNGs can end up saturated to white
    # after going through libx264's default color pipeline.
    cmd = [
        "ffmpeg", "-y",
        "-framerate", str(fps),
        "-start_number", str(start),
        "-i", str(frames_dir / pattern),
        "-frames:v", str(n_frames),
        "-vf", "format=rgb24",
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", str(crf),
        "-pix_fmt", "yuv420p",
        str(out_path),
    ]
    print(f"[{frames_dir.name}] {n_frames} frames -> {out_path}")
    print("  $ " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--src", required=True, type=Path,
                        help="Root dir containing one sub-dir per sequence (e.g. UDM10/BIx4)")
    parser.add_argument("--dst", required=True, type=Path,
                        help="Output directory for the generated MP4 files")
    parser.add_argument("--fps", type=int, default=25,
                        help="Frame rate of the generated videos (default: 25)")
    parser.add_argument("--crf", type=int, default=17,
                        help="x264 CRF; 0 = lossless (yuv420p can misbehave), "
                             "17 = visually lossless and robust (default: 17)")
    return parser.parse_args()


def main():
    args = parse_args()

    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg not found on PATH. Install it first (e.g. `apt-get install ffmpeg`).")

    if not args.src.is_dir():
        sys.exit(f"Source directory does not exist: {args.src}")

    sequences = find_sequences(args.src)
    if not sequences:
        sys.exit(f"No sub-directory with PNG frames found under {args.src}")

    print(f"Found {len(sequences)} sequence(s) under {args.src}:")
    for name, _ in sequences:
        print(f"  - {name}")
    print()

    for name, frames_dir in sequences:
        convert(frames_dir, args.dst / f"{name}.mp4", fps=args.fps, crf=args.crf)

    print(f"\nDone. {len(sequences)} video(s) written to {args.dst}")


if __name__ == "__main__":
    main()
