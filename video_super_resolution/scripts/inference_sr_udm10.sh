#!/bin/bash
# STAR inference over the UDM10 (BIx4) dataset pre-converted to MP4.
#
# Prerequisites:
#   1. Run utils_data/udm10_png_to_video.sh first so that
#      ${video_folder_path} contains 10 MP4 files (000.mp4 ... 009.mp4).
#   2. Place the pretrained weight at ./pretrained_weight/model.pt
#      (light_deg.pt is recommended for UDM10-BIx4 bicubic degradation).
#
# Override paths/options with env vars, e.g.:
#   VIDEO_DIR=/other/path MODEL_PATH=/weights/light_deg.pt \
#       bash video_super_resolution/scripts/inference_sr_udm10.sh
set -euo pipefail

# -------- User-configurable paths --------
VIDEO_DIR="${VIDEO_DIR:-/mnt/HDD_raid1/yjcho/data/UDM10/LQ-Video}"
TXT_FILE="${TXT_FILE:-./input/text/udm10_prompts.txt}"
MODEL_PATH="${MODEL_PATH:-./pretrained_weight/model.pt}"
SAVE_DIR="${SAVE_DIR:-./results/udm10}"

# -------- Inference hyper-parameters --------
FRAME_LENGTH="${FRAME_LENGTH:-32}"   # lower if you hit OOM (e.g. 16)
UPSCALE="${UPSCALE:-4}"
STEPS="${STEPS:-15}"
SOLVER_MODE="${SOLVER_MODE:-fast}"

# -------- Sanity checks --------
if [ ! -d "${VIDEO_DIR}" ]; then
    echo "ERROR: VIDEO_DIR does not exist: ${VIDEO_DIR}" >&2
    exit 1
fi
if [ ! -f "${TXT_FILE}" ]; then
    echo "ERROR: TXT_FILE does not exist: ${TXT_FILE}" >&2
    exit 1
fi
if [ ! -f "${MODEL_PATH}" ]; then
    echo "ERROR: MODEL_PATH does not exist: ${MODEL_PATH}" >&2
    echo "Download a weight from https://huggingface.co/SherryX/STAR" >&2
    exit 1
fi

mkdir -p "${SAVE_DIR}"

# Collect MP4 files in sorted order so the line-to-video matching is deterministic.
mapfile -t mp4_files < <(find "${VIDEO_DIR}" -maxdepth 1 -type f -name "*.mp4" | sort)
mapfile -t lines < <(grep -v '^\s*$' "${TXT_FILE}")

echo "Videos found: ${#mp4_files[@]}"
echo "Prompt lines: ${#lines[@]}"

if [ "${#mp4_files[@]}" -ne "${#lines[@]}" ]; then
    echo "ERROR: MP4 count (${#mp4_files[@]}) != prompt line count (${#lines[@]})" >&2
    echo "Edit ${TXT_FILE} so it has exactly ${#mp4_files[@]} non-empty lines." >&2
    exit 1
fi

for i in "${!mp4_files[@]}"; do
    mp4_file="${mp4_files[$i]}"
    line="${lines[$i]}"
    file_name="$(basename "${mp4_file}" .mp4)"

    echo "==============================================================="
    echo "[$((i+1))/${#mp4_files[@]}] ${mp4_file}"
    echo "  prompt: ${line}"
    echo "  out   : ${SAVE_DIR}/${file_name}.mp4"
    echo "==============================================================="

    python ./video_super_resolution/scripts/inference_sr.py \
        --solver_mode "${SOLVER_MODE}" \
        --steps "${STEPS}" \
        --input_path "${mp4_file}" \
        --model_path "${MODEL_PATH}" \
        --prompt "${line}" \
        --upscale "${UPSCALE}" \
        --max_chunk_len "${FRAME_LENGTH}" \
        --file_name "${file_name}.mp4" \
        --save_dir "${SAVE_DIR}"
done

echo "All UDM10 videos processed. Results: ${SAVE_DIR}"
