#!/usr/bin/env bash
# Apply HDMI labels/icons from config/inputs.json (needs jq + root SSH).
set -euo pipefail
: "${TV_IP:?set TV_IP}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
jq -r 'to_entries[] | "\(.key) \(.value.label) \(.value.icon)"' "$DIR/config/inputs.json" |
while read -r port label icon; do
  echo "Setting $port -> $label ($icon)"
  # TODO verify on device: external input settings service/key names differ by webOS version
  ssh root@"$TV_IP" "luna-send -n 1 luna://com.webos.service.eim/setInputLabel '{\"id\":\"$port\",\"label\":\"$label\",\"icon\":\"$icon\"}'"
done
