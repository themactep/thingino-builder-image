#!/bin/bash
#
# Convenience launcher for the Thingino standardized build environment.
# Prefers the hosted image (ghcr.io/themactep/thingino-builder-image).
#
# Usage:
#   ./run.sh                 # drop into an interactive shell with firmware tree mounted
#   ./run.sh make            # run make inside the container (camera selector etc. will work)
#
# The current working directory (or ./workspace) is mounted at /workspace inside the container.
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

# Prepare workspace
if [ -d "workspace" ]; then
    WORKSPACE_DIR="$(pwd)/workspace"
else
    WORKSPACE_DIR="$(pwd)"
fi

mkdir -p "$WORKSPACE_DIR/dl"

echo "Workspace: $WORKSPACE_DIR"
echo "Image:     $IMAGE"
echo

COMMON_OPTS=(
    --rm -it
    -v "$WORKSPACE_DIR:/workspace"
    -v "$WORKSPACE_DIR/dl:/home/builder/dl"
    -w /workspace
)

if [ "$ENGINE" = "podman" ]; then
    COMMON_OPTS+=( --userns=keep-id )
else
    # Best effort numeric user mapping for Docker
    COMMON_OPTS+=( --user "$(id -u):$(id -g)" )
fi

if [ $# -eq 0 ]; then
    echo "Starting interactive shell..."
    exec "$ENGINE" run "${COMMON_OPTS[@]}" "$IMAGE" /bin/bash
else
    echo "Running inside container: $*"
    exec "$ENGINE" run "${COMMON_OPTS[@]}" "$IMAGE" "$@"
fi
