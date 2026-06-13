# thingino-builder-image

Podman (and Docker) image for building [Thingino firmware](https://github.com/themactep/thingino-firmware) in a standardized and reproducible environment.

Pre-built images are published to the GitHub Container Registry:

- `ghcr.io/themactep/thingino-builder-image:latest`

## Quick start (recommended)

### Podman (preferred on Linux desktops)

```bash
# 1. Install podman if needed
sudo apt update && sudo apt install podman

# 2. Clone the firmware you want to build
git clone --recurse-submodules https://github.com/themactep/thingino-firmware.git ~/thingino-firmware
cd ~/thingino-firmware

# 3. Create a download cache directory (highly recommended for speed)
mkdir -p dl

# 4. Run a build inside the hosted container
podman run --rm -it --userns=keep-id \
  -v "$PWD:/workspace" \
  -v "$PWD/dl:/home/builder/dl" \
  -w /workspace \
  ghcr.io/themactep/thingino-builder-image:latest \
  make
```

The `--userns=keep-id` flag ensures files written inside the container are owned by your real user on the host.

### Docker

```bash
docker run --rm -it --user "$(id -u):$(id -g)" \
  -v "$PWD:/workspace" \
  -v "$PWD/dl:/home/builder/dl" \
  -w /workspace \
  ghcr.io/themactep/thingino-builder-image:latest \
  make
```

> Note: Docker user mapping is less seamless than Podman's keep-id. Some git operations or tools that expect a passwd entry may behave slightly differently. Podman is recommended.

## Selecting a camera and other make targets

All normal make targets and variables work. Example:

```bash
# Interactive camera selection is handled by the firmware's helper scripts when available
podman run ... ghcr.io/themactep/thingino-builder-image:latest make

# Or pass CAMERA directly for CI / scripting
podman run ... -e CAMERA=wyze_cam_v3 make
```

Common targets (executed inside the container):

- `make` or `make all` – incremental parallel build
- `make fast` – clean parallel build
- `make dev` – serial build with V=1 (easier to debug errors)
- `make menuconfig`, `make linux-menuconfig`, etc.
- `make cleanbuild`
- OTA: `make ota IP=192.168.1.123 CAMERA=...`

See the firmware repository for the full list of targets and `CAMERA=` values.

## Using the firmware's docker helper scripts (optional)

The firmware repo contains `docker-build.sh` and `Makefile.docker` that wrap container usage, provide camera pickers (fzf/whiptail), and handle image building locally.

Those scripts currently default to building a local image (often tagged `thingino-builder` or `thingino-builder-image`) from the Dockerfile shipped inside the firmware tree. You can point them at the hosted image by exporting `DOCKER_IMAGE=ghcr.io/themactep/thingino-builder-image` (adjust the scripts or set `CONTAINER_ENGINE` appropriately).

For the simplest "just works" hosted experience, the direct `podman run ...` examples above are sufficient and avoid a full local image rebuild on every machine.

## Building the container image locally (for customization or air-gapped)

```bash
# From inside this (thingino-builder-image) repository
podman build -t thingino-builder-image:local -f Containerfile .

# Then use your local tag instead of the ghcr reference.
```

You can also pass build args to bake a specific UID/GID (mainly useful if not using `--userns=keep-id`):

```bash
podman build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) \
  -t thingino-builder-image:local -f Containerfile .
```

## Environment variables

- `BR2_DL_DIR` – location of the Buildroot external downloads cache (mounted to `/home/builder/dl` in the examples).
- `CAMERA`, `GROUP`, `IP`, etc. – passed straight through to the Thingino Makefile.

## Why a separate builder image?

- Fast onboarding: one `podman run` and you have a known-good toolchain.
- Reproducible builds across developer machines and CI.
- The heavy dependency layer (apt packages + base image) is built and cached centrally.
- The firmware source tree stays on the host and can be any branch or dirty checkout.

## Updating the image

```bash
podman pull ghcr.io/themactep/thingino-builder-image:latest
```

The image is rebuilt automatically by CI on pushes to the main branch of this repository.

## License

Contents are MIT licensed (see the thingino project for details).
