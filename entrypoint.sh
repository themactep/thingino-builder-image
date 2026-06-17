#!/bin/bash
# entrypoint.sh for thingino-builder-image
# Performs lightweight runtime setup then executes the requested command.
# This runs as the image's default user (builder) in published images.

set -e

# Ensure common mount points are marked safe for git (in case the tree is bind-mounted at runtime).
# The Containerfile already sets a few at image build time.
git config --global --add safe.directory /workspace 2>/dev/null || true
git config --global --add safe.directory /home/builder 2>/dev/null || true
git config --global --add safe.directory /home/builder/build 2>/dev/null || true
git config --global --add safe.directory "$(pwd)" 2>/dev/null || true

# Ensure the download cache directory is writable by the ubuntu user.
# This handles volumes seeded from the dl cache image (files owned by root).
sudo chown ubuntu:ubuntu /home/ubuntu/dl 2>/dev/null || true

# If the user provided BR2_DL_DIR via the environment we respect it (already handled by ENV + runtime -e).
# Nothing else to do here for a pure build environment.

# Execute the requested command (make, bash, menuconfig wrapper, etc.)
exec "$@"
