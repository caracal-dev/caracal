# Bazzite kernel OCI — provides pre-built kernel RPMs
ARG FEDORA_VERSION=43
ARG ARCH=x86_64
ARG KERNEL_REF="ghcr.io/bazzite-org/kernel-bazzite:latest-f${FEDORA_VERSION}-${ARCH}"
FROM ${KERNEL_REF} AS kernel

# Build context: scripts live in build_files/, branding assets in system_files/assets/
FROM scratch AS ctx
COPY build_files /
COPY system_files/assets /assets

# Homebrew — provides /usr/share/homebrew.tar.zst and brew-setup.service
# https://github.com/ublue-os/brew
FROM ghcr.io/ublue-os/brew:latest AS brew

# Base Image — Fedora Kinoite (KDE) with Universal Blue additions
FROM quay.io/fedora-ostree-desktops/kinoite:43

### Pre-install system configuration files
## Copied directly into the image before the build script runs.
## /etc: KDE/XDG config, hostname, skel (vendor defaults)
## /usr: Plasma themes, Plymouth config, ujust recipes, runtime install scripts
COPY system_files/etc /etc
COPY system_files/usr /usr

# Copy Homebrew archive and setup service from the brew stage
# Credit: https://github.com/ublue-os/brew contributors
COPY --from=brew /system_files /

### Kernel swap
## Replace the stock Fedora kernel with the Bazzite kernel.
## Must run before build.sh so the correct kernel headers are in place.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=kernel,src=/,dst=/rpms/kernel \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/install-kernel

### Build
## All package installation, branding, and plugin setup
## happens in build.sh. Scripts are at /ctx/, branding assets at /ctx/assets/.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build.sh

### Lint
RUN bootc container lint
