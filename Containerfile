FROM ghcr.io/ublue-os/akmods:main-fedora-43 AS akmods
# Bazzite kernel OCI — provides pre-built kernel RPMs
ARG FEDORA_VERSION=43
ARG ARCH=x86_64
ARG KERNEL_REF="ghcr.io/bazzite-org/kernel-bazzite:latest-f${FEDORA_VERSION}-${ARCH}"
FROM ${KERNEL_REF} AS kernel
FROM ghcr.io/bazzite-org/nvidia-drivers:latest-f${FEDORA_VERSION}-${ARCH} AS nvidia

# Homebrew — provides /usr/share/homebrew.tar.zst and brew-setup.service
# https://github.com/ublue-os/brew
# Routed through ctx so rsync deploys it in the same layer as our system files,
# avoiding the OCI layer-level /etc vs /usr/etc conflict (same pattern as Aurora).
FROM ghcr.io/ublue-os/brew:latest AS brew


# Build context: scripts live in build_files/, branding assets in assets/images/,
# system files in system_files/shared/ (deployed via rsync in build.sh, same as Aurora)
FROM scratch AS ctx
COPY build_files /
COPY assets/images /assets
COPY system_files/shared /system_files/shared
COPY --from=brew /system_files /system_files/shared
COPY --from-akmods /rpms/kmod-evdi/*.rpm /tmp/akmods/

# Base Image — Fedora Kinoite (KDE) with Universal Blue additions
FROM quay.io/fedora-ostree-desktops/kinoite:43 AS caracal

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

### Initramfs
## Build initramfs after branding/custom assets are in place so Plymouth uses
## the Caracal logo during early boot, not the base Fedora asset from the
## pre-branding filesystem snapshot.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-initramfs

### Lint
RUN bootc container lint

### NVIDIA image
## Separate target for users who want to bootc switch to Caracal with NVIDIA
## drivers preinstalled. Disk and ISO builds continue to use the regular image.
FROM caracal AS caracal-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=nvidia,src=/rpms/nvidia,dst=/tmp/rpms/nvidia \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/install-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-initramfs

RUN bootc container lint

FROM caracal AS final
