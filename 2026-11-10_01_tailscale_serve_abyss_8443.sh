#!/usr/bin/env bash
# abyss on https://g7.tail5dff8b.ts.net:8443/; see 2026-11-10_01_tailscale_serve_abyss_8443.md.
# Run in your own terminal: bash ~/repos/plans/2026-11-10_01_tailscale_serve_abyss_8443.sh
set -euo pipefail

logs=~/handoff-logs
mkdir -p "$logs"

sudo tailscale serve --bg --https=8443 http://127.0.0.1:8001 2>&1 | tee "$logs/13a-tailscale-serve-8443.log"
tailscale serve status 2>&1 | tee -a "$logs/13a-tailscale-serve-8443.log"

echo "done; log in $logs/13a-tailscale-serve-8443.log"
