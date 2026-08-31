# Universal Blue akmods OCI images provide pre-built kernel and kmod RPMs.
ARG FEDORA_VERSION=44
ARG ARCH=x86_64
ARG KERNEL_FLAVOR=ogc
ARG KERNEL_REF="ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}"
ARG NVIDIA_REF="ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA_VERSION}"
FROM ${KERNEL_REF} AS akmods
FROM ${NVIDIA_REF} AS akmods-nvidia

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
COPY system_files/stage /system_files/stage
COPY system_files/nvidia /system_files/nvidia
COPY --from=brew /system_files /system_files/shared

# Base Image — Fedora Kinoite (KDE) with Universal Blue additions
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION} AS caracal

### Kernel swap
## Replace the stock Fedora kernel with the OGC/Bazzite kernel from ublue akmods.
## Must run before build.sh so the correct kernel headers are in place.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/rpms/kernel \
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

### DX image
## Developer workstation variant, similar to Aurora/Bazzite DX. It keeps the
## Caracal audio stack and adds Docker, VSCodium, libvirt/QEMU tooling, Cockpit,
## flatpak-builder, tracing/profiling tools, and container/VM workflow helpers.
FROM caracal AS caracal-dx

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    IMAGE_NAME=caracal-dx /usr/bin/bash /ctx/build-dx.sh

RUN bootc container lint

### Stage image
## Minimal performance image for live stage rigs. It keeps the Caracal kernel,
## audio tuning, and Windows-plugin compatibility stack, but replaces the full
## Plasma desktop workflow with a Wayfire console session focused on Carla.
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION} AS caracal-stage

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/rpms/kernel \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/install-kernel

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-stage.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-initramfs

RUN bootc container lint

### Stage ARM image
## ARM64 variant of caracal-stage. Uses kernel-rt from @kernel-vanilla/fedora
## COPR for low-latency audio on aarch64, and skips Wine/yabridge (x86_64-only
## stack, not available on aarch64).
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_VERSION} AS caracal-stage-arm

### Kernel swap — RT kernel
## Replace the stock Fedora kernel with kernel-rt from the @kernel-vanilla/fedora
## COPR. Provides a PREEMPT_RT real-time kernel for aarch64 low-latency audio.
## Must run before build-stage-arm.sh so the correct kernel headers are in place.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/install-kernel-arm

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-stage-arm.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-initramfs

RUN bootc container lint

### NVIDIA image
## Separate target for users who want to bootc switch to Caracal with NVIDIA
## drivers preinstalled. Disk and ISO builds continue to use the regular image.
FROM caracal AS caracal-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/rpms/nvidia \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    IMAGE_NAME=caracal-nvidia /ctx/install-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build-initramfs

RUN bootc container lint

### DX NVIDIA image
## NVIDIA variant of Caracal DX. Built from caracal-nvidia so the proprietary
## driver stack is installed before the developer workstation additions.
FROM caracal-nvidia AS caracal-dx-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    IMAGE_NAME=caracal-dx-nvidia /usr/bin/bash /ctx/build-dx.sh

RUN bootc container lint

### Gaming image
## Bazzite-based gaming variant. Bazzite already ships the kernel, NVIDIA
## drivers, Steam, Lutris, MangoHud, and the rest of the gaming stack.
## This target only layers Caracal branding and runtime files on top.
## Excluded from ISO/disk builds due to image size.
FROM ghcr.io/ublue-os/bazzite:latest AS caracal-gaming

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    IMAGE_NAME=caracal-gaming /ctx/build-gaming.sh

RUN bootc container lint

### Gaming NVIDIA image
## Bazzite-NVIDIA-based gaming variant. Same as caracal-gaming but with
## NVIDIA drivers preinstalled by Bazzite.
## Excluded from ISO/disk builds due to image size.
FROM ghcr.io/ublue-os/bazzite-nvidia:latest AS caracal-gaming-nvidia

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    IMAGE_NAME=caracal-gaming-nvidia /ctx/build-gaming.sh

RUN bootc container lint

FROM caracal AS final
