# MetaForge Bridge on Linux

> Link your **ARC Raiders** account to [metaforge.app](https://metaforge.app) on Linux —
> even though MetaForge **only ships a Windows installer**.
> *by Hermy & Linux Fertxo* — tested on CachyOS + Hyprland (Oct 2026).

[🇪🇸 Versión en español](docs/GUIA-es.md)

---

## The problem

MetaForge Bridge authorizes your **Embark** account (ARC Raiders) with MetaForge. The only catch on
Linux: the site **only offers a Windows installer**
(`downloads.metaforge.app/bridge/MetaForgeBridgeSetup.exe`), and the flow starts with a
`metaforge://…` **deep link** that your browser opens.

The good news: the bridge is built with **Rust + Dioxus** and uses **WebKitGTK** on Linux. And since
you play via **Steam**, you do **not** need **WebView2** (that's only used by the *Epic* path).

---

## The approach

Run the **official Windows installer** inside ARC Raiders' **Proton prefix** and launch it with
`protontricks-launch`. Proton ships the shims that give access to your **native Steam**, so the bridge
gets its ticket just fine.

```
Browser (Firefox)  ──metaforge://…──►  host handler (relay)
                                          │
                                          ▼
     protontricks-launch --appid 1808500 "metaforge-bridge.exe" "metaforge://…"
                                          │
                     (inside the Proton prefix: Steam → Embark → MetaForge)
```

**Why this is nice:** you use the **official binary** → when a new version drops, you just reinstall the `.exe`.

---

## Requirements

- **Steam** installed and **running, logged in** (the ticket comes from there).
- **protontricks** (`protontricks` + `protontricks-launch`).
  - Arch/CachyOS: `sudo pacman -S protontricks`
- **ARC Raiders** (appid **1808500**) configured with Proton — or **any** Steam game that uses Proton.

---

## Steps

### 1. Install the bridge into the prefix (silent)

```bash
# download the official installer
curl -L -o ~/Downloads/MetaForgeBridgeSetup.exe \
  https://downloads.metaforge.app/bridge/MetaForgeBridgeSetup.exe

# install it INSIDE ARC Raiders' Proton prefix (Steam running)
protontricks-launch --appid 1808500 ~/Downloads/MetaForgeBridgeSetup.exe /S
```

It lands in:
```
~/.steam/steam/steamapps/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe
```

### 2. Relay + `metaforge://` scheme handler

The browser can't launch a program "inside a prefix", so we use a **relay**: a script that receives the
deep-link URL and launches the `.exe` inside the prefix.

`~/.local/bin/metaforge-bridge-relay.sh`:
```bash
#!/usr/bin/env bash
EXE="$HOME/.steam/steam/steamapps/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe"
export DISPLAY="${DISPLAY:-:0}"     # adjust if you don't use XWayland (:0)
exec protontricks-launch --appid 1808500 "$EXE" "$@"
```
```bash
chmod +x ~/.local/bin/metaforge-bridge-relay.sh
```

`~/.local/share/applications/metaforge-bridge.desktop`:
```ini
[Desktop Entry]
Type=Application
Name=MetaForge Bridge
Exec=/home/YOURUSER/.local/bin/metaforge-bridge-relay.sh %u
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/metaforge;
Categories=Utility;
```

Register the handler:
```bash
update-desktop-database ~/.local/share/applications
xdg-mime default metaforge-bridge.desktop x-scheme-handler/metaforge
# check:
xdg-mime query default x-scheme-handler/metaforge     # -> metaforge-bridge.desktop
```

### 3. Link your account

1. **Steam running.**
2. In the browser: **metaforge.app → Connect Embark**.
3. The bridge window appears (it may take a few seconds the first time — Proton has to start the
   prefix) and runs the Steam → Embark flow. ✅

---

## Updating

Versions come out often. This script does it in one step — see
[`scripts/metaforge-bridge-update.sh`](scripts/metaforge-bridge-update.sh):

```bash
scripts/metaforge-bridge-update.sh          # updates
scripts/metaforge-bridge-update.sh --check  # only checks
```

---

## Pitfalls (the ones that bit us)

- **Steam must be running.** Otherwise: *"Steam is not available"*.
- **WebView2 is only needed for Epic.** Not for Steam. (That's why Proton works.)
- **Close the bridge before updating.** If the `.exe` is in use, the installer won't replace it and you
  stay on the old version without noticing. The script closes it first.
- **The deep link expires** (~5 min). Click *Connect Embark* and let the flow run.
- **The handler must use the relay.** A `.desktop` pointing straight at the `.exe` won't work, because
  the browser can't launch processes "inside" the prefix.
- **The site is behind Cloudflare** for `curl` to `metaforge.app/...` (403). For the installer use
  `downloads.metaforge.app` (CDN, no challenge).

---

## Verify & diagnose

```bash
# handler in place?
xdg-mime query default x-scheme-handler/metaforge           # metaforge-bridge.desktop

# installed version?
strings -e l -n 3 \
  "$HOME/.steam/steam/steamapps/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe" \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'

# handler smoke test (no linking):
gio open "metaforge://probe"    # opens the bridge (or says invalid link = handler OK)
```

**Support log** (writes errors only; no new line after an attempt = all good):
```
…/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge/Bridge/data/metaforge-bridge-support.log
```
Typical codes: `protocol_malformed_jws` (bad deep link), `embark_token_exchange_failed`
(the Embark authorization failed — try updating the bridge), `complete_*` (couldn't finish on MetaForge).

---

## Note for MetaForge (feedback)

We'd love a **native Linux build**. The bridge is built with **Rust + Dioxus**, which
**compiles natively on Linux** (it already uses `wry` → WebKitGTK): basically `cargo build --release`
swapping `steam_api64.dll` for `libsteam_api.so`. That would remove this workaround and add
**Steam Deck** support for free. 🙏

---

*by Hermy & Linux Fertxo — twitch.tv/linux_fertxo*
