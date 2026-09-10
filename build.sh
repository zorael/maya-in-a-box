#!/bin/bash
set -euo pipefail

# Example custom command:
# MAYA_SRC=~/maya-extracted CONTAINER_NAME="maya-test" SKIP_SEPARATE_HOME=1 \
#   ./build.sh --no-cache path/to/dir/with/Containerfile

MAYA_SRC="${MAYA_SRC:-$HOME/maya-src}"
CONTAINER_NAME="${CONTAINER_NAME:-maya}"
CONTAINER_IMAGE="localhost/${CONTAINER_NAME}-rocky9"

if [[ ! -f "$MAYA_SRC/MayaConfig.pit" ]]; then
    echo "[!] MAYA_SRC='$MAYA_SRC' doesn't seem to point to a valid extracted Maya installer" >&2
    should_exit=1
fi

if podman container exists "$CONTAINER_NAME"; then
    echo "[!] CONTAINER_NAME='$CONTAINER_NAME' seems to already exist" >&2
    should_exit=1
fi

if [[ -n "${should_exit:-}" ]]; then
    # Something is wrong
    exit 1
fi

# If no arguments were passed to this script, set them to a single "." (as $1)
# so podman build looks to the current directory for the Containerfile if nothing else was supplied
[[ $# -eq 0 ]] && set -- "."

echo "[*] podman build"
podman build \
    --security-opt label=disable \
    --volume "$MAYA_SRC":/mnt/maya-src:ro \
    --tag "$CONTAINER_IMAGE" \
    "$@"

# Allow for disabling a separate home for the distrobox by setting SKIP_SEPARATE_HOME
HOME_ARGS=()
[[ -n "${SKIP_SEPARATE_HOME:-}" ]] || HOME_ARGS=( --home "$HOME/.distrobox/$CONTAINER_NAME" )

echo
echo "[*] distrobox create"
distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$CONTAINER_IMAGE" \
    "${HOME_ARGS[@]}" \
    --init

# There is already a trailing empty space output from the previous command
#echo
echo "[*] distrobox finalise and first run"
distrobox enter "$CONTAINER_NAME" -- /opt/maya-install/first-run.sh

MAYA_RUN_PATH="$HOME/.local/bin/maya-run"

if [[ -n "${SKIP_EXPORTS:-}" ]]; then
    echo "[!] SKIP_EXPORTS is set; not exporting 'maya-run' wrapper script" >&2
elif [[ -f "$MAYA_RUN_PATH" ]]; then
    echo "[!] 'maya-run' wrapper script already exists at '$MAYA_RUN_PATH'; not re-exporting" >&2
else
    echo "[*] Exporting Maya run script"
    mkdir -p ~/.local/bin
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/maya-run
fi

DESKTOP_FILE_NAME="Autodesk-Maya2027.desktop"

if [[ -n "${SKIP_EXPORTS:-}" ]]; then
    echo "[!] SKIP_EXPORTS is set; not exporting modified .desktop file" >&2
elif [[ -f "$HOME/.local/share/applications/$CONTAINER_NAME-$DESKTOP_FILE_NAME" ]]; then
    echo "[!] .desktop file already exists; not re-exporting" >&2
else
    echo "[*] Exporting modified Maya .desktop file"
    echo
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --app "$DESKTOP_FILE_NAME"
    echo
fi

echo "---"
echo "[*] Build and setup complete, start Maya with 'maya-run' or via your desktop application launcher"
echo "[*] Inside the container, if '~/.local/bin' is placed earlier in your \$PATH"
echo "    than '/usr/local/bin' is, the exported host-system 'maya-run' will take priority."
echo "    Invoke the full path '/usr/local/bin/maya-run' to bypass the exported wrapper."
