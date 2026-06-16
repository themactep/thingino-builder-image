# syntax=docker/dockerfile:1

# Thingino Firmware Build Environment
# thingino-builder-image — Standardized, reproducible container image for compiling Thingino firmware.
# Pre-built images are hosted at ghcr.io/themactep/thingino-builder-image

FROM ubuntu:26.04

LABEL org.opencontainers.image.title="Thingino Builder Image"
LABEL org.opencontainers.image.description="Standardized container image for building Thingino firmware"
LABEL org.opencontainers.image.source="https://github.com/themactep/thingino-builder-image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Thingino"
LABEL maintainer="Paul Philippov <paul@thingino.com>"

# Install build dependencies for Thingino + Buildroot (host side)
# Keep list in sync with the one used inside thingino-firmware repo when possible.
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y \
        ack \
        apt-transport-https \
        apt-utils \
        autoconf \
        bc \
        bison \
        build-essential \
        busybox \
        ca-certificates \
        ccache \
        cmake \
        cpio \
        curl \
        dialog \
        file \
        flex \
        fzf \
        gawk \
        git \
        golang-go \
        libcrypt-dev \
        libncurses-dev \
        libusb-1.0-0-dev \
        locales \
        lzop \
        m4 \
        mc \
        make \
        mtools \
        nano \
        nodejs \
        npm \
        parted \
        perl \
        python3 \
        python3-dev \
        python3-jinja2 \
        python3-jsonschema \
        python3-setuptools \
        python3-yaml \
        ripgrep \
        rsync \
        shfmt \
        ssh \
        sudo \
        swig \
        u-boot-tools \
        unzip \
        vim \
        wget \
        whiptail \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Make vim the default editor (handy inside the container for menuconfig etc.)
RUN update-alternatives --install /usr/bin/editor editor /usr/bin/vim 1 && \
    update-alternatives --set editor /usr/bin/vim && \
    update-alternatives --install /usr/bin/vi vi /usr/bin/vim 1 && \
    update-alternatives --set vi /usr/bin/vim

# Switch from uutils coreutils install to GNU install (uutils has known bugs
# that break Buildroot: https://github.com/uutils/coreutils/issues/12166)
RUN update-alternatives --install /usr/bin/install install /usr/bin/gnuinstall 100

# Install GitHub CLI (needed for release uploads and notifications in CI)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

# CA certificates and locale (UTF-8 is expected by many build scripts)
RUN update-ca-certificates && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Configure the existing ubuntu user for build use
RUN echo "ubuntu:ubuntu" | chpasswd && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Standard location for Buildroot's download cache (can be overridden with -e BR2_DL_DIR=...)
ENV BR2_DL_DIR=/home/ubuntu/dl

# Default working directory. Most usage overrides this with -w /workspace
# together with a bind mount of the firmware tree.
WORKDIR /home/ubuntu

# Make the (future) mount point a safe git directory so users can run git commands inside.
RUN git config --global --add safe.directory /workspace && \
    git config --global --add safe.directory /home/ubuntu && \
    git config --global alias.up 'pull --rebase --autostash'

# Copy and prepare entrypoint (lightweight runtime initialization)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER ubuntu

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default to an interactive shell; typical usage is to override with make ... or a specific target.
CMD ["/bin/bash"]

