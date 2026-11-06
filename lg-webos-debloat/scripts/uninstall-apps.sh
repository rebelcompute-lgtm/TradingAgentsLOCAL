#!/usr/bin/env bash
# PERMANENTLY uninstall every removable app that has a launcher icon (removeLaunchPoint on a
# removable app deletes the app; there is no restore). Keeps Homebrew Channel (SSH access!).
#   ./scripts/uninstall-apps.sh          dry-run: list what would go
#   ./scripts/uninstall-apps.sh --apply
set -euo pipefail
: "${TV_IP:?set TV_IP}"
KEEP="org.webosbrew.hbchannel"
run() { ssh -n -o BatchMode=yes root@"$TV_IP" "$@"; }
ls_() { run "rm -f /tmp/ls.out; (luna-send -n 1 -f '$1' '$2' > /tmp/ls.out 2>&1 &)
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s /tmp/ls.out ] && break; sleep 1; done; sleep 2; cat /tmp/ls.out"; }
lp=$(ls_ luna://com.webos.applicationManager/listLaunchPoints '{}')
echo "$lp" > "$(dirname "$0")/../config/launchpoints-before-uninstall.json"
jq -r --arg k "$KEEP" '.launchPoints[] | select(.removable==true and .id!=$k) | [.launchPointId,.title]|@tsv' <<<"$lp" |
while IFS=$'\t' read -r lpid title; do
  if [[ "${1:-}" == "--apply" ]]; then
    echo "$title: $(ls_ luna://com.webos.applicationManager/removeLaunchPoint "{\"launchPointId\":\"$lpid\"}" | tr -d '\n ')"
  else echo "[dry-run] uninstall $title ($lpid)"; fi
done
