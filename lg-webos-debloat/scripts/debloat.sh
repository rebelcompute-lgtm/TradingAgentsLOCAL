#!/usr/bin/env bash
# Hide/disable preinstalled apps listed in config/bloat.txt on a rooted LG webOS TV.
# Verified on UN7000PUB (webOS 5.x, fw 04.63.25). See README "What actually works".
#
#   ./scripts/debloat.sh            dry-run (prints what it would do)
#   ./scripts/debloat.sh --apply    hide / lock apps
#   ./scripts/debloat.sh --restore  undo --apply   (a reboot is needed for hidden apps)
#
# Two mechanisms, chosen per app from config/installed-apps.json (scripts/list-apps.sh):
#  * App lives on writable storage (/media/cryptofs, removable:true, e.g. Gaming Portal):
#      back up its appinfo.json, set "visible":false. Icon disappears after a reboot.
#      Restore = copy backup back + reboot. Hide+restore each worked once in testing, BUT
#      on later reboots the TV rewrote these app dirs (LG app updater/verifier) and undid the
#      edit (twice, 3 apps). Treat as best-effort: re-run --apply after reboots, and check.
#      NOTE: do NOT use removeLaunchPoint on these - it UNINSTALLS the app (not recoverable).
#  * System app (read-only /usr/palm or /mnt/otncabi):
#      launch point can't be removed and appinfo can't be edited, so use
#      lockApp {"id","lock":true|false} spoofed as com.webos.appInstallService.
#      Blocks launching only (takes effect immediately); an icon, if any, stays visible.
#      Lock state did NOT survive a reboot in testing (launch succeeded afterwards).
#      Not lockable (lockable:false) apps are skipped with a message.
set -euo pipefail
: "${TV_IP:?set TV_IP}"
MODE=dry
case "${1:-}" in
  --apply) MODE=apply ;;
  --restore) MODE=restore ;;
  "") ;;
  *) echo "usage: $0 [--apply|--restore]"; exit 2 ;;
esac
DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLED="$DIR/config/installed-apps.json"
BACKUP=/media/developer/backup/appinfo
command -v jq >/dev/null || { echo "jq required"; exit 1; }
[[ -f "$INSTALLED" ]] || { echo "Run scripts/list-apps.sh first so IDs are verified."; exit 1; }
run() { ssh -n -o BatchMode=yes root@"$TV_IP" "$@"; }

# luna-send over ssh can return empty output when piped on a busy TV, so send to a
# file in the background and poll for the reply.
lunasend() { # $1 = uri, $2 = json
  run "rm -f /tmp/ls.out; (luna-send -n 1 -a com.webos.appInstallService -f '$1' '$2' > /tmp/ls.out 2>&1 &)
       for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do [ -s /tmp/ls.out ] && break; sleep 1; done; cat /tmp/ls.out"
}

need_reboot=0
while read -r app; do
  [[ -z "$app" || "$app" == \#* ]] && continue
  entry=$(jq -c --arg id "$app" '.apps[] | select(.id==$id)' "$INSTALLED")
  [[ -n "$entry" ]] || { echo "skip (not in installed-apps.json): $app"; continue; }
  folder=$(jq -r .folderPath <<<"$entry")
  if ! run "[ -d '$folder' ]"; then echo "skip (no longer installed on TV): $app"; continue; fi

  if [[ "$folder" == /media/cryptofs/* ]]; then
    f="$folder/appinfo.json"; b="$BACKUP/$app.appinfo.json"
    case $MODE in
      dry)     echo "[dry-run] hide $app: backup $f -> $b; set visible:false (reboot needed)" ;;
      apply)
        run "mkdir -p $BACKUP; [ -e '$b' ] || cp '$f' '$b'
             if grep -q '\"visible\"' '$f'; then sed -i 's/\"visible\" *: *true/\"visible\":false/' '$f'
             else sed 's/^{/{\"visible\":false,/' '$f' > /tmp/ai.$$ && cp /tmp/ai.$$ '$f' && rm /tmp/ai.$$; fi; sync"
        echo "hidden (after reboot): $app"; need_reboot=1 ;;
      restore)
        if run "[ -e '$b' ]"; then run "cp '$b' '$f'; sync"; echo "restored (after reboot): $app"; need_reboot=1
        else echo "no backup, nothing to restore: $app"; fi ;;
    esac
  else
    if [[ "$(jq -r .lockable <<<"$entry")" != "true" ]]; then echo "skip (system app, not lockable): $app"; continue; fi
    lock=true; [[ $MODE == restore ]] && lock=false
    payload="{\"id\":\"$app\",\"lock\":$lock}"
    if [[ $MODE == dry ]]; then echo "[dry-run] lockApp $payload"; continue; fi
    out=$(lunasend luna://com.webos.applicationManager/lockApp "$payload" | tr -d '\n ')
    echo "lockApp $app lock=$lock -> $out"
  fi
done < "$DIR/config/bloat.txt"

if (( need_reboot )); then
  echo
  echo "Reboot the TV for icon changes to take effect:  ssh root@$TV_IP reboot"
  echo "(Do not accept firmware updates; Homebrew Channel 'block system update' should stay ON.)"
fi
