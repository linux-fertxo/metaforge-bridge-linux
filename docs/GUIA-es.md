# MetaForge Bridge en Linux

> Cómo enlazar tu cuenta de **ARC Raiders** con [metaforge.app](https://metaforge.app) desde Linux,
> cuando MetaForge **solo distribuye un instalador de Windows**.
> *by Hermy & Linux Fertxo* — probado en CachyOS + Hyprland (oct-2026).

---

## El problema

MetaForge Bridge es el puente que autoriza tu cuenta **Embark** (ARC Raiders) con la web de MetaForge.
El único inconveniente en Linux es que **en la web solo hay un instalador de Windows**
(`https://metaforge.app/api/arc-raiders/embark/app-auth/bridge-download`), y el flujo empieza con un **deep-link**
`metaforge://…` que abre el navegador.

La buena noticia: **el puente está hecho con Rust + Dioxus** y su parte web tira de **WebKitGTK** en Linux.
Y como juegas por **Steam**, **no necesitas WebView2** (eso solo lo usa la vía *Epic*).

---

## La solución

Ejecutar el **instalador oficial de Windows** dentro del **prefix Proton** de ARC Raiders y lanzarlo
con `protontricks-launch`. Proton trae los *shims* que dan acceso al **Steam nativo**, así que el
puente obtiene su ticket sin problema.

```
Navegador (Firefox)  ──metaforge://…──►  handler del host (relé)
                                             │
                                             ▼
      protontricks-launch --appid 1808500 "metaforge-bridge.exe" "metaforge://…"
                                             │
                        (dentro del prefix Proton: Steam → Embark → MetaForge)
```

**La ventaja:** usas el **binario oficial** → cuando salga una versión nueva, solo reinstalas el `.exe`.

---

## Requisitos

- **Steam** instalado y **abierto con la sesión iniciada** (de ahí sale el ticket).
- **protontricks** (`protontricks` + `protontricks-launch`).
  - Arch/CachyOS: `sudo pacman -S protontricks`
- **ARC Raiders** (appid **1808500**) con Proton configurado — o **cualquier** juego de Steam que use Proton.

---

## Pasos

### 1. Instalar el bridge dentro del prefix (silencioso)

**NOTA:** El enlace de descarga puede cambiar, si no estás seguro por favor descárgalo manualmente desde tu navegador.

```bash
# baja el instalador oficial
curl -L -o ~/Descargas/MetaForgeBridgeSetup.exe \
  https://downloads.metaforge.app/bridge/MetaForgeBridgeSetup-0.1.8.exe

# instálalo DENTRO del prefix Proton de ARC Raiders (Steam abierto)
protontricks-launch --appid 1808500 ~/Descargas/MetaForgeBridgeSetup.exe /S
```

Queda en:
```
~/.steam/steam/steamapps/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe
```

### 2. Relé + handler del esquema `metaforge://`

El navegador no puede lanzar un programa "dentro de un prefix", así que hacemos un **relé**: un script
que recibe la URL del deep-link y lanza el `.exe` en el prefix.

`~/.local/bin/metaforge-bridge-relay.sh`:
```bash
#!/usr/bin/env bash
EXE="$HOME/.steam/steam/steamapps/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe"
export DISPLAY="${DISPLAY:-:0}"     # ajusta si no usas XWayland (:0)
exec protontricks-launch --appid 1808500 "$EXE" "$@"
```
```bash
chmod +x ~/.local/bin/metaforge-bridge-relay.sh
```

***NOTA: reemplaza TU_USUARIO por tu nombre de usuario!*
`~/.local/share/applications/metaforge-bridge.desktop`:
```ini
[Desktop Entry]
Type=Application
Name=MetaForge Bridge
Exec=/home/TU_USUARIO/.local/bin/metaforge-bridge-relay.sh %u
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/metaforge;
Categories=Utility;
```

Registra el handler:
```bash
update-desktop-database ~/.local/share/applications
xdg-mime default metaforge-bridge.desktop x-scheme-handler/metaforge
# comprobar:
xdg-mime query default x-scheme-handler/metaforge     # -> metaforge-bridge.desktop
```

### 3. Enlazar

1. **Steam abierto.**
2. En el navegador: **metaforge.app → Connect Embark**.
3. Aparecerá la ventana del bridge (a veces tarda unos segundos: Proton levanta el prefix) y hará
   el flujo Steam → Embark. ✅

---

## 5. Actualizar cuando salga versión nueva

Las versiones se suceden a menudo. Este script lo hace en un paso:
[`scripts/metaforge-bridge-update.sh`](scripts/metaforge-bridge-update.sh):

```bash
scripts/metaforge-bridge-update.sh          # actualiza
scripts/metaforge-bridge-update.sh --check  # sólo comprueba
```

## Dificultades (las que nos mordieron)

- **Steam tiene que estar abierto.** Si no: *"Steam is not available"*.
- **WebView2 solo hace falta para Epic.** Por Steam, no. (Por eso funciona en Proton.)
- **Cierra el bridge antes de actualizar**: si el `.exe` está en uso, el instalador no lo reemplaza y
  sigues con la versión vieja sin enterarte. El script lo cierra antes.
- **El deep-link caduca** (~5 min). Pulsa *Connect Embark* y deja que siga el flujo seguido.
- **El handler debe usar el relé**: un `.desktop` que apunte directo al `.exe` no funciona, porque el
  navegador no puede lanzar procesos "dentro" del prefix.
- **La web bloquea con Cloudflare** si haces `curl` a `metaforge.app/...` (403). Para el instalador usa
  `downloads.metaforge.app` (CDN, sin challenge).

---

## Verificación y diagnóstico

```bash
# ¿handler bien puesto?
xdg-mime query default x-scheme-handler/metaforge           # metaforge-bridge.desktop

# ¿versión instalada?
strings -e l -n 3 \
  "$HOME/.steam/steam/steamapps/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge Bridge/metaforge-bridge.exe" \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$'

# prueba del handler sin enlazar:
gio open "metaforge://probe"    # se abrirá el bridge (o dirá enlace inválido = handler OK)
```

**Log de soporte** (solo escribe errores; sin línea nueva tras un intento = todo OK):
```
…/compatdata/1808500/pfx/drive_c/users/steamuser/AppData/Local/MetaForge/Bridge/data/metaforge-bridge-support.log
```
Códigos típicos: `protocol_malformed_jws` (deep-link inválido), `embark_token_exchange_failed`
(la autorización con Embark falló — prueba a actualizar el bridge), `complete_*` (fallo al cerrar la
operación en MetaForge).

---

## Nota para MetaForge (feedback)

Nos encantaría un **build nativo de Linux**. El bridge está hecho con **Rust + Dioxus**, que
**compila nativo en Linux** (usa `wry` → WebKitGTK): básicamente sería `cargo build --release`
cambiando `steam_api64.dll` por `libsteam_api.so`. Eso eliminaría este *trabajo alrededor* y daría
soporte de paso a **Steam Deck**. 🙏

---
*by Hermy & Linux Fertxo — twitch.tv/linux_fertxo*
