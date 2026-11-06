# lg-webos-debloat

Debloat an LG webOS TV and give its HDMI inputs proper labels/icons
(e.g. **Apple TV** on HDMI 1, **Nintendo Switch** on HDMI 2).

> Status: tested on a real UN7000PUB (webOS 5.x, fw 04.63.25, rooted). See "What actually works".

## Target
LG UN7000PUB (2020 US UHD series, believed to run webOS 5.x; confirm in
Settings > General > About This TV). Rootability depends on your exact
firmware version: check https://www.webosbrew.org/ (rooting guide) before
doing anything, and do not accept firmware updates until you know.

## Approach
1. **Root / dev access** via the community [webOS Brew](https://www.webosbrew.org/)
   project (Homebrew Channel + `dev-manager-desktop` / `ares-cli`). Supported models
   and exploits vary by firmware; check their compatibility list first and do NOT
   update firmware before rooting.
2. **Debloat**: disable (not delete) preinstalled apps listed in `config/bloat.txt`
   so it is reversible. See `scripts/debloat.sh`.
3. **Inputs**: set labels/icons for HDMI ports from `config/inputs.json`
   via `scripts/set-inputs.sh`. Stock webOS lets you pick a name/icon under
   Settings > Inputs; "Apple TV" is not a stock icon, so this script tries a custom
   label and falls back to the closest stock icon.
4. Also turn off telemetry/ads: Settings > General > About This TV > User
   Agreements (disable Live Plus / personalized ads) and reset the Advertising ID.

## Setup (rooted TV)
1. Root with dejavuln-autoroot or faultmanager-autoroot (see their READMEs); don't update firmware.
2. Open Homebrew Channel, enable SSH, and add your public key (`ssh-copy-id root@$TV_IP`).
3. `./scripts/list-apps.sh` then edit `config/bloat.txt` using the real IDs it prints.

## Usage
```bash
export TV_IP=192.168.1.50
./scripts/debloat.sh        # dry-run by default; pass --apply to execute
./scripts/set-inputs.sh
```
Requires `ssh` access to the rooted TV (user `root`) .

## What actually works (tested on UN7000PUB)
Run luna-send on the TV with output to a file (`cmd > /tmp/x &` then read it); piping over ssh
sometimes returns nothing on this TV, especially in the first minutes after boot (load ~36).
Reboots take ~6 min until the luna bus answers properly.

**Input labels (works, verified):** `luna://com.webos.service.eim/setDeviceInfo`
`{"id":"HDMI_1","label":"Apple TV","icon":"appletv.png","forceIcon":true}`. There is no
`setInputLabel`. Stock icons live in `/usr/palm/plugins/inputapps/assets/small/`
(`appletv.png`, `gameconsole.png`, `xbox.png`, ...). `set-inputs.sh --status/--restore`.
Not yet checked: whether labels survive a reboot.

**Hiding apps: no good reversible mechanism found.**
- `lockApp` (`{"id","lock":bool}`, caller spoofed as `com.webos.appInstallService`) blocks launch
  only, keeps the icon, and did not persist across a reboot.
- `removeLaunchPoint` is refused for system apps (`removable:false`: "this launch point cannot be
  removable"). For removable apps it **uninstalls the app** (files under `/media/cryptofs/apps`
  deleted; `com.lgshop.app` / Shop Time is gone from `listApps`). A reboot does not bring it back,
  and `addLaunchPoint` can't either (it needs the installed app; for an installed app it just
  creates a *duplicate* launch point, `{"id":appId}`, removable via its returned launchPointId).
- Setting `"visible":false` in a removable app's `appinfo.json` (backup first) hid the icon after a
  reboot once and restoring the backup brought it back, but on later reboots the TV rewrote the
  app directories and reverted the edit. `debloat.sh` uses this + `lockApp` as best-effort.
- ACR/ad components are headless system apps; whether `lockApp` actually stops them is unverified.
  Use Settings > General > About This TV > User Agreements to turn off Live Plus/ads as well.
- To get Shop Time back: LG's store may reinstall it on its own; otherwise a factory reset or an
  installer ipk is needed.

## Safety
`./scripts/debloat.sh --restore` undoes `--apply` (reboot afterwards). Never use removeLaunchPoint on
removable apps (uninstalls them). You risk bricking/voiding
warranty; proceed at your own risk.
