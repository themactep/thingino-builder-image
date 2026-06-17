# Thingino Builder Image

Standardized Podman/Docker image for building [Thingino firmware](https://github.com/themactep/thingino-firmware).

## Architecture

This repo builds and publishes a **single container image** (`ghcr.io/themactep/thingino-builder-image:latest`). The image provides the toolchain and build deps; the firmware source tree is bind-mounted at runtime.

- `Containerfile` — main build image (Ubuntu 26.04 + Buildroot deps + GitHub CLI + locale + entrypoint). Declares `VOLUME /home/ubuntu/dl` for persistent download cache.
- `Containerfile.dl` — separate "download cache volume" image (busybox-based, contains pre-downloaded Buildroot source tarballs). Declares `VOLUME /dl/` for volume seeding.
- `entrypoint.sh` — runtime setup: marks bind-mounted dirs as safe for git, ensures dl directory ownership, then execs the command.
- `run.sh` — transparent podman/docker wrapper that detects engine, mounts firmware tree, creates and manages a named dl volume (`thingino-dl-cache`), forwards env.
- `prune-dl.sh` — removes git repos from `dl/` to reduce image size (called from CI workflows).

## Key commands

```bash
# Build local image
podman build -t thingino-builder-image:local -f Containerfile .
podman build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) ... # custom uid/gid

# Run a build (with named volume for persistent dl cache)
podman run --rm -it --userns=keep-id \
  -v "$PWD:/workspace" \
  -v thingino-dl-cache:/home/ubuntu/dl \
  -w /workspace \
  ghcr.io/themactep/thingino-builder-image:latest \
  make

# Or use run.sh (auto-detects podman vs docker, firmware tree, dl cache volume)
./run.sh                 # make
./run.sh fast            # make fast
./run.sh dev             # make dev
./run.sh bash            # interactive shell
CAMERA=wyze_cam_v3 ./run.sh fast   # env forwarded
```

## CI

- **`build-and-push.yml`** — pushes to main/master: builds + pushes multi-arch (`linux/amd64,linux/arm64`) builder image AND a fresh dl cache image to GHCR. Also runs on PRs (build only, no push). The dl cache job checks the latest `buildroot-dl-cache` release tag from `themactep/thingino-firmware` against the label on the current `ghcr.io/themactep/thingino-dl:latest` image; only downloads, prunes git repos, and pushes a new image if the release has changed. The release tag is stored in the image label `dl.source.release`.
- **`build-dl-image.yml`** — manual trigger only (`workflow_dispatch`). Same dl cache build, for offline or debug use.

## Gotchas

- **`uutils` bug on Ubuntu**: Buildroot chokes on uutils `install`. The Containerfile explicitly sets `update-alternatives` to use `/usr/bin/gnuinstall` instead.
- **`--userns=keep-id`** is the recommended podman flag for file ownership. Docker users get `--user $(id -u):$(id -g)`.
- **Download cache** (`BR2_DL_DIR`) defaults to `/home/ubuntu/dl` inside the container. `run.sh` uses a named volume `thingino-dl-cache` and auto-seeds it from `ghcr.io/themactep/thingino-dl:latest` on first use (pre-built download cache from thingino-firmware CI release artifacts). Direct `podman run` users should use `-v thingino-dl-cache:/home/ubuntu/dl`.
- **Entrypoint re-runs `git config --global --add safe.directory`** at runtime for bind-mounted trees.
- **`run.sh`** checks for `Makefile + configs/` to auto-detect a firmware tree. Falls back to cloning into `./workspace/firmware`. Download cache is managed as a named Docker volume, not a bind mount.
- **License**: MIT.
