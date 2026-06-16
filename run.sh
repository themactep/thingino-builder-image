#!/bin/bash
#
# Convenience launcher for the Thingino standardized build environment.
# Prefers the hosted image (ghcr.io/themactep/thingino-builder-image).
#
# The script is intentionally transparent:
#   ./run.sh                 # equivalent to "make" inside the container
#   ./run.sh fast            # equivalent to "make fast"
#   ./run.sh dev             # equivalent to "make dev"
#   ./run.sh ota IP=...      # equivalent to "make ota IP=..."
#   ./run.sh menuconfig      # equivalent to "make menuconfig"
#   ./run.sh bash            # drop into an interactive shell instead of make
#
# Environment variables are passed through transparently:
#   CAMERA=wyze_cam_v3 ./run.sh fast
#
# Workspace / firmware tree handling:
# - If the current directory looks like a thingino-firmware tree, it is used directly.
# - Otherwise a firmware checkout is maintained in ./workspace/firmware (cloned on first use).
# - Download cache lives in ./workspace/dl (or next to the firmware tree).
#

set -e

IMAGE="ghcr.io/themactep/thingino-builder-image:latest"

# Detect engine
if command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
    echo "Using podman"
elif command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
    echo "Using docker"
else
    echo "Error: podman or docker is required." >&2
    echo "Install podman: sudo apt install podman" >&2
    exit 1
fi

# Prepare workspace: ensure we mount a real thingino-firmware tree
if [ -f "Makefile" ] && [ -d "configs" ]; then
    # Current dir looks like a firmware checkout (has Makefile + configs/)
    WORKSPACE_DIR="$(pwd)"
    echo "Detected thingino-firmware tree in current directory."
else
    # Look for an existing firmware tree in common locations
    if [ -d "workspace/firmware" ] && [ -f "workspace/firmware/Makefile" ]; then
        WORKSPACE_DIR="$(pwd)/workspace/firmware"
    elif [ -d "workspace/thingino" ] && [ -f "workspace/thingino/Makefile" ]; then
        WORKSPACE_DIR="$(pwd)/workspace/thingino"
    else
        # Auto-setup: clone into workspace/firmware (only when run from builder repo etc.)
        WORKSPACE_DIR="$(pwd)/workspace/firmware"
        mkdir -p "$(dirname "$WORKSPACE_DIR")"

        if [ ! -d "$WORKSPACE_DIR" ]; then
            echo "No firmware tree found."
            echo "Cloning https://github.com/themactep/thingino-firmware.git into $WORKSPACE_DIR ..."
            echo "(This will take a while the first time due to submodules.)"
            git clone --recurse-submodules https://github.com/themactep/thingino-firmware.git "$WORKSPACE_DIR"
        fi
    fi
fi

# Download cache (BR2_DL_DIR). Keep it outside the tree when possible so it can be shared.
if [ -d "workspace/dl" ] || [ ! -d "$WORKSPACE_DIR/dl" ]; then
    DL_DIR="$(pwd)/workspace/dl"
else
    DL_DIR="$WORKSPACE_DIR/dl"
fi
mkdir -p "$DL_DIR"

echo "Firmware workspace: $WORKSPACE_DIR"
echo "Download cache:     $DL_DIR"
echo "Image:              $IMAGE"
echo

COMMON_OPTS=(
    --rm -it
    -v "$WORKSPACE_DIR:/workspace"
    -v "$DL_DIR:/home/ubuntu/dl"
    -w /workspace
)

if [ "$ENGINE" = "podman" ]; then
    COMMON_OPTS+=( --userns=keep-id )
else
    # Best effort numeric user mapping for Docker
    COMMON_OPTS+=( --user "$(id -u):$(id -g)" )
fi

# Forward environment for transparency (CAMERA, IP, BR2_*, etc.).
# With podman we use --env-host for maximum transparency.
ENV_OPTS=()
if [ "$ENGINE" = "podman" ]; then
    ENV_OPTS+=(--env-host)
else
    # Docker: explicitly forward the variables that matter for builds
    for var in CAMERA GROUP IP BR2_DL_DIR VERBOSE V MAKEFLAGS CCACHE_DIR TERM; do
        if [ -n "${!var+x}" ]; then
            ENV_OPTS+=(-e "$var")
        fi
    done
fi

# Determine container command.
# Default: treat *all* arguments given to run.sh as arguments to "make".
# This makes the script completely transparent.
if [ $# -eq 0 ]; then
    CONTAINER_CMD=(make)
elif [ "$1" = "shell" ] || [ "$1" = "bash" ] || [ "$1" = "/bin/bash" ]; then
    # Request an interactive shell instead of make
    shift
    CONTAINER_CMD=(/bin/bash "$@")
elif [ "$1" = "make" ]; then
    # User explicitly said "make ..." — pass through verbatim
    CONTAINER_CMD=("$@")
else
    # Normal case: args become make arguments
    CONTAINER_CMD=(make "$@")
fi

echo "Running inside container: ${CONTAINER_CMD[*]}"
exec "$ENGINE" run "${ENV_OPTS[@]}" "${COMMON_OPTS[@]}" "$IMAGE" "${CONTAINER_CMD[@]}"
