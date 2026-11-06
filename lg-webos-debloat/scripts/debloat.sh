#!/usr/bin/env bash
# Disable preinstalled apps listed in config/bloat.txt on a rooted LG webOS TV.
set -euo pipefail
: "${TV_IP:?set TV_IP}"
APPLY=0; RESTORE=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
[[ "${1:-}" == "--restore" ]] && APPLY=1 && RESTORE=1
DIR="$(cd "$(dirname "$0")/.." && pwd)"
run() { ssh root@"$TV_IP" "$@"; }

if (( APPLY )); then
  run 'mkdir -p /media/developer/backup && cp -r /var/luna/preferences /media/developer/backup/ 2>/dev/null || true'
fi
while read -r app; do
  [[ -z "$app" || "$app" == \#* ]] && continue
  # TODO verify on device: lockApp/ unlockApp hides an app from the launcher without deleting it
  method=lockApp; (( RESTORE )) && method=unlockApp
  cmd="luna-send -n 1 luna://com.webos.applicationManager/$method '{\"id\":\"$app\"}'"
  if (( APPLY )); then run "$cmd"; else echo "[dry-run] $cmd"; fi
done < "$DIR/config/bloat.txt"
