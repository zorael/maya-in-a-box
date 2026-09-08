#!/bin/bash
set -euo pipefail

# Example custom command:
# MAYA_SRC=~/maya-extracted CONTAINER_NAME="maya-test" ./build.sh --no-cache path/to/dir/with/Containerfile

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

if [[ "$should_exit" ]]; then
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

echo
echo "[*] distrobox create"
distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$CONTAINER_IMAGE" \
    --home ~/.distrobox/"$CONTAINER_NAME" \
    --init

# There is already a trailing empty space output from the previous command
#echo
echo "[*] distrobox finalise and first run"
distrobox enter "$CONTAINER_NAME" -- /opt/maya-install/first-run.sh

if [[ -f "$HOME/.local/bin/maya-run" ]]; then
    echo "[!] 'maya-run' wrapper script already exists at '~/.local/bin/maya-run'; not re-exporting" >&2
else
    echo "[*] Exporting Maya run script"
    mkdir -p ~/.local/bin
    distrobox enter "$CONTAINER_NAME" -- distrobox-export --bin /usr/local/bin/maya-run
fi

echo "---"
echo "[*] Build and setup complete, start Maya with 'maya-run'"
echo "[*] Inside the container, if '~/.local/bin' is placed earlier in your \$PATH"
echo "    than '/usr/local/bin' is, the exported host-system 'maya-run' will take priority."
echo "    Invoke the full path '/usr/local/bin/maya-run' to bypass the exported wrapper."
