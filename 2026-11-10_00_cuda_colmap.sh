#!/usr/bin/env bash
# CUDA toolkit and COLMAP on g7; see 2026-11-10_00_cuda_colmap.md.
# Run in your own terminal: bash ~/repos/plans/2026-11-10_00_cuda_colmap.sh
set -euo pipefail

logs=~/handoff-logs
mkdir -p "$logs"

sudo apt-get update 2>&1 | tee "$logs/12a-apt-update.log"
sudo apt-get install -y cuda-toolkit colmap 2>&1 | tee "$logs/12b-apt-cuda-colmap.log"
# colmap 3.12.6-4 links libPoseLib.so without depending on the package that ships it.
sudo apt-get install -y libposelib 2>&1 | tee "$logs/12c-apt-libposelib.log"

echo "done; logs in $logs/12a-12c"
