# Build context: scripts live in build_files/, branding assets in system_files/assets/
FROM scratch AS ctx
COPY build_files /
COPY system_files/assets /assets

# Base Image — Fedora Kinoite (KDE) with Universal Blue additions
FROM quay.io/fedora-ostree-desktops/kinoite:43

### Pre-install system configuration files
## Copied directly into the image before the build script runs.
## /usr/etc: KDE/XDG config, hostname, skel (bootc convention: distro configs go in /usr/etc)
## /usr: Plasma themes, Plymouth config, ujust recipes, runtime install scripts
COPY system_files/etc /usr/etc
COPY system_files/usr /usr

### Build
## All package installation, kernel swap, branding, and plugin setup
## happens in build.sh. Scripts are at /ctx/, branding assets at /ctx/assets/.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/run \
    /ctx/build.sh

### Lint
RUN bootc container lint
