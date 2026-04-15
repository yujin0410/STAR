#!/bin/bash
# Convert the UDM10 BIx4 PNG sequences under the user's data root into MP4 files
# that the STAR inference pipeline can consume.
#
# Usage:
#   bash utils_data/udm10_png_to_video.sh
#
# Override paths/fps with environment variables if needed, e.g.:
#   SRC=/data/UDM10/BIx4 DST=/data/UDM10/LQ-Video FPS=30 bash utils_data/udm10_png_to_video.sh
set -euo pipefail

SRC="${SRC:-/mnt/HDD_raid1/yjcho/data/UDM10/BIx4}"
DST="${DST:-/mnt/HDD_raid1/yjcho/data/UDM10/LQ-Video}"
FPS="${FPS:-25}"
CRF="${CRF:-17}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python "${SCRIPT_DIR}/udm10_png_to_video.py" \
    --src "${SRC}" \
    --dst "${DST}" \
    --fps "${FPS}" \
    --crf "${CRF}"
