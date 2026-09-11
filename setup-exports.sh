#!/bin/bash

HOST_HOME="/run/host/home/$(id -un)"

if [[ ! -d "$HOST_HOME" ]]; then
    echo "[x] Failed to resolve host home path" >&2
    exit 1
fi

###############################################################################

MAYA_RUN_PATH="$HOST_HOME/.local/bin/maya-run"

if [[ -f "$MAYA_RUN_PATH" ]]; then
    echo "[!] Wrapper script already exists; not re-exporting" >&2
else
    echo "[*] Exporting wrapper script"
    mkdir -p "$HOST_HOME/.local/bin"
    distrobox-export --bin /usr/local/bin/maya-run
fi

###############################################################################

# We don't know CONTAINER_NAME from build.sh but we do know CONTAINER_ID
DESKTOP_FILE_NAME="Autodesk-Maya2027.desktop"
DESKTOP_FULL_NAME="$CONTAINER_ID-$DESKTOP_FILE_NAME"

if [[ -f "$HOST_HOME/.local/share/applications/$DESKTOP_FULL_NAME" ]]; then
    echo "[!] '$DESKTOP_FULL_NAME' already exists; not re-exporting" >&2
else
    echo "[*] Exporting .desktop file"
    echo
    distrobox-export --app "$DESKTOP_FILE_NAME"
    echo
fi
