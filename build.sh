#!/bin/bash
set -euo pipefail

MAYA_SRC="${MAYA_SRC:-$HOME/maya-src}"
CONTAINER_NAME="maya-test3"
CONTAINER_IMAGE="localhost/maya-test3-rocky9"
REPO_DIR="${1:-.}"

if [[ ! -f "$MAYA_SRC/MayaConfig.pit" ]]; then
    echo "[!] \$MAYA_SRC '$MAYA_SRC' doesn't seem to point to a valid extracted Maya installer" >&2
    exit 1
fi

echo "[*] podman build"
podman build --no-cache --security-opt label=disable -v "$MAYA_SRC":/mnt/maya-src:ro \
    -t "$CONTAINER_IMAGE" "$REPO_DIR"

echo
echo "[*] distrobox create"
distrobox create --name "$CONTAINER_NAME" --image "$CONTAINER_IMAGE" \
    --home ~/.distrobox/"$CONTAINER_NAME" --init

echo
echo "[*] distrobox finalise and first run"
distrobox enter "$CONTAINER_NAME" -- /opt/maya-install/first-run.sh

if [[ -f "$HOME/.local/bin/maya-run" ]]; then
    echo
    echo "[!] 'maya-run' script already exists at ~/.local/bin/maya-run; not re-exporting"
else
    echo
    echo "[*] Exporting Maya run script to ~/.local/bin/maya-run"
    mkdir -p ~/.local/bin
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/maya-run
fi

echo
echo "[*] Build and setup complete, start Maya with 'maya-run'"
