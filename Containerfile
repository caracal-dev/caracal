# Bazzite kernel OCI — provides pre-built kernel RPMs
ARG FEDORA_VERSION=43
ARG ARCH=x86_64
ARG KERNEL_REF="ghcr.io/bazzite-org/kernel-bazzite:latest-f${FEDORA_VERSION}-${ARCH}"
FROM ${KERNEL_REF} AS kernel

# Homebrew — provides /usr/share/homebrew.tar.zst and brew-setup.service
# https://github.com/ublue-os/brew
# Routed through ctx so rsync deploys it in the same layer as our system files,
# avoiding the OCI layer-level /etc vs /usr/etc conflict (same pattern as Aurora).
FROM ghcr.io/ublue-os/brew:latest AS brew

FROM golang:1.25 AS caracal-software-installer-build
WORKDIR /src
COPY caracal-software-installer/go.mod caracal-software-installer/go.sum ./
RUN go mod download
COPY caracal-software-installer/ .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/caracal-software-installer ./cmd/caracal-software-installer

# Build context: scripts live in build_files/, branding assets in system_files/assets/,
# system files in system_files/shared/ (deployed via rsync in build.sh, same as Aurora)
FROM scratch AS ctx
COPY caracal/build_files /
COPY caracal/system_files/assets /assets
COPY caracal/system_files/shared /system_files/shared
COPY --from=brew /system_files /system_files/shared
COPY --from=caracal-software-installer-build /out/caracal-software-installer /system_files/shared/usr/bin/caracal-software-installer
COPY caracal-software-installer/scripts /system_files/shared/usr/lib/caracal-software-installer/scripts
COPY caracal-software-installer/assets /system_files/shared/usr/share/caracal-software-installer/assets
COPY caracal-software-installer/logo.txt /system_files/shared/usr/share/caracal-software-installer/logo.txt

# Base Image — Fedora Kinoite (KDE) with Universal Blue additions
FROM quay.io/fedora-ostree-desktops/kinoite:43

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
