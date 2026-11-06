#!/usr/bin/env bash
# Apply HDMI labels/icons from config/inputs.json via luna://com.webos.service.eim/setDeviceInfo
# (VERIFIED on UN7000PUB, fw 04.63.25; the old "setInputLabel" method does not exist).
# Icons are files in /usr/palm/plugins/inputapps/assets/small/ on the TV (appletv.png,
# gameconsole.png, xbox.png, ps3.png, roku.png, bluray.png, pc.png, ...).
#
#   ./scripts/set-inputs.sh            dry-run
#   ./scripts/set-inputs.sh --apply    set labels/icons
#   ./scripts/set-inputs.sh --restore  back to stock "HDMI N" / HDMI_N.png for ports in inputs.json
#   ./scripts/set-inputs.sh --status   show current label/icon of every input
set -euo pipefail
: "${TV_IP:?set TV_IP}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE=dry
case "${1:-}" in --apply) MODE=apply;; --restore) MODE=restore;; --status) MODE=status;; "") ;; *) echo "usage: $0 [--apply|--restore|--status]"; exit 2;; esac
command -v jq >/dev/null || { echo "jq required"; exit 1; }
run() { ssh -n -o BatchMode=yes root@"$TV_IP" "$@"; }
# luna-send over ssh can return empty when piped; write to a file and poll.
lunasend() { # $1 = uri, $2 = json
  run "rm -f /tmp/ls.out; (luna-send -n 1 -f '$1' '$2' > /tmp/ls.out 2>&1 &)
       for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do [ -s /tmp/ls.out ] && break; sleep 1; done; cat /tmp/ls.out"
}
EIM=luna://com.webos.service.eim
if [[ $MODE == status ]]; then
  lunasend $EIM/getAllInputStatus '{}' | jq -r '.devices[] | [.id,.label,.icon,.connected] | @tsv'
  exit 0
fi
jq -r 'to_entries[] | [.key, .value.label, .value.icon] | @tsv' "$DIR/config/inputs.json" |
while IFS=$'\t' read -r port label icon; do
  if [[ $MODE == restore ]]; then n=${port##*_}; label="HDMI $n"; icon="${port}.png"; fi
  payload=$(jq -nc --arg id "$port" --arg l "$label" --arg i "$icon" '{id:$id,label:$l,icon:$i,forceIcon:true}')
  if [[ $MODE == dry ]]; then echo "[dry-run] setDeviceInfo $payload"; continue; fi
  echo "$port -> $label ($icon): $(lunasend $EIM/setDeviceInfo "$payload" | tr -d '\n ')"
done
