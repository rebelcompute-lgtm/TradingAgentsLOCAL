#!/usr/bin/env bash
# Dump installed app ids/titles from the TV so config/bloat.txt uses real IDs.
set -euo pipefail
: "${TV_IP:?set TV_IP}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/config/installed-apps.json"
ssh root@"$TV_IP" "luna-send -n 1 -f luna://com.webos.applicationManager/listApps '{}'" > "$OUT"
echo "Saved $OUT"
command -v jq >/dev/null && jq -r '.apps[] | "\(.id)\t\(.title)\t\(.systemApp // false)"' "$OUT" | sort
