#!/bin/bash
set -euo pipefail

DEFAULT_WEB_BROWSER="brave-browser.desktop"

###############################################################################

echo "[*] Setting up licensing"
/opt/maya-install/setup-licensing.sh

# setup-licensing.sh outputs a message on error and exits non-0
# set -e will end this script immediately if so

###############################################################################

echo "[*] Creating identity manager desktop file"
mkdir -p ~/.local/share/applications

cat << EOF > ~/.local/share/applications/com.autodesk.AdskIdentityManager.desktop
[Desktop Entry]
Name=Autodesk Identity Manager
Exec=/opt/Autodesk/AdskIdentityManager/Current/AdskIdentityManager %u
Type=Application
MimeType=x-scheme-handler/adskidmgr;x-scheme-handler/adsk.idmgr;
NoDisplay=true
EOF

###############################################################################

echo "[*] Updating desktop database"
update-desktop-database ~/.local/share/applications

###############################################################################

echo "[*] Setting default web browser"
mkdir -p ~/.config
xdg-settings set default-web-browser "$DEFAULT_WEB_BROWSER" &>/dev/null || true
xdg-mime default "$DEFAULT_WEB_BROWSER" x-scheme-handler/http x-scheme-handler/https &>/dev/null || true

###############################################################################

echo "[*] Copying fonts to host"

HOST_HOME="/run/host/home/$(id -un)"

if [[ ! -d "$HOST_HOME" ]]; then
    echo "[!] Failed to resolve host home path" >&2
    exit 1  # also skips host-exec of .distroboxrc below
fi

FONT_DIR="${HOST_HOME}/.local/share/x11-fonts"
mkdir -p "$FONT_DIR"

for subdir in 100dpi 75dpi; do
    dir="/usr/share/X11/fonts/$subdir"
    [[ -d "$dir" ]] || continue

    if [[ -f "$dir/fonts.dir" ]]; then
        cp -r "$dir" "$FONT_DIR/"
        continue;
    fi

    echo "[!] '$dir/fonts.dir' is missing; google 'mkfontdir'" >&2
    # non-fatal, don't exit
done

###############################################################################

if [[ -e "$HOST_HOME/.distroboxrc" ]]; then
    echo "[*] Invoking .distroboxrc on host"
    distrobox-host-exec sh "$HOST_HOME/.distroboxrc"
fi
