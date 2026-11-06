# lg-webos-debloat

Debloat an LG webOS TV and give its HDMI inputs proper labels/icons
(e.g. **Apple TV** on HDMI 1, **Nintendo Switch** on HDMI 2).

> Status: scaffold. Commands below are a starting point and **must be verified on
> your TV model/webOS version**. Nothing here has been run against a real TV.

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

## Safety
Disabling apps is reversible via `./scripts/debloat.sh --restore`. Keep a backup
of `/var/luna/preferences` first (script does this). You risk bricking/voiding
warranty; proceed at your own risk.
