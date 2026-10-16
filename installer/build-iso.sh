#!/usr/bin/env bash
# Builds a Caracal installer ISO (aurora-iso / bootc-isos pattern).
#
# usage: build-iso.sh <output.iso> <payload-image> [live-env-image] [bundle-flatpaks]
#   payload-image      image the ISO installs — baked into the live
#                      environment as an OCI layout, so installs are fully
#                      offline
#   live-env-image     image whose rootfs becomes the live desktop
#                      (defaults to the payload image; override for flavors
#                      like caracal-stage so the live session has a desktop)
#   bundle-flatpaks    on | off (default on) — bakes installer/iso-flatpaks
#                      into the live environment for offline installs
#
# Env:
#   LIVESYS_SESSION    kde (default) | gnome — live desktop session
#   AUTHFILE           optional registry auth file (default
#                      ~/.docker/config.json, only used when present)
#
# Uses rootful podman (sudo): the live-environment build needs sys_admin for
# the /proc/sys remount and dracut inside the build sandbox, and the ISO
# assembly mounts the image rootfs. The assembler is
# installer/iso_files/build_iso.sh, vendored from ublue-os/titanoboa
# (bootc-isos contract).
set -euo pipefail

OUT="${1:?usage: build-iso.sh <output.iso> <payload-image> [live-env-image] [bundle-flatpaks]}"
PAYLOAD="${2:?missing payload image}"
LIVE_ENV="${3:-${PAYLOAD}}"
# Accept on/off/true/false; normalize to true/false — the live build checks
# strictly for "true", so raw "on" would silently skip the flatpak step.
BUNDLE="${4:-on}"
case "${BUNDLE,,}" in
on | true) BUNDLE="true" ;;
off | false) BUNDLE="false" ;;
*)
  echo "ERROR: bundle-flatpaks must be on|off|true|false, got '${BUNDLE}'" >&2
  exit 1
  ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTHFILE="${AUTHFILE:-${HOME}/.docker/config.json}"
authfile_args=()
if [[ -f "${AUTHFILE}" ]]; then
    authfile_args=(--authfile "${AUTHFILE}")
fi
LIVE_TAG="localhost/caracal-live:iso-build-$$"

if ! sudo podman image exists "${PAYLOAD}" 2>/dev/null; then
    sudo podman pull "${authfile_args[@]}" "${PAYLOAD}"
fi
if [[ "${LIVE_ENV}" != "${PAYLOAD}" ]] && ! sudo podman image exists "${LIVE_ENV}" 2>/dev/null; then
    sudo podman pull "${authfile_args[@]}" "${LIVE_ENV}"
fi

sudo podman build \
    --cap-add sys_admin \
    --security-opt label=disable \
    --build-arg BASE_IMAGE="${PAYLOAD}" \
    --build-arg LIVE_ENV_IMAGE="${LIVE_ENV}" \
    --build-arg BUNDLE_FLATPAKS="${BUNDLE}" \
    --build-arg LIVESYS_SESSION="${LIVESYS_SESSION:-kde}" \
    --tag "${LIVE_TAG}" \
    -f "${REPO_ROOT}/installer/Containerfile" \
    "${REPO_ROOT}/installer"

OUT_DIR="$(mkdir -p "$(dirname "${OUT}")" && cd "$(dirname "${OUT}")" && pwd)"
OUT_NAME="$(basename "${OUT}")"

sudo podman run --rm -i \
    -e OUTPUT_ISO_NAME="${OUT_NAME}" \
    --security-opt label=disable \
    --volume "${REPO_ROOT}/installer/iso_files/build_iso.sh:/src/build_iso.sh:ro" \
    --mount type=image,source="${LIVE_TAG}",dst=/rootfs \
    --volume "${OUT_DIR}:/output" \
    quay.io/fedora/fedora:latest \
    /src/build_iso.sh

# Hand the ISO (and its output directory, so callers can write the sibling
# CHECKSUM) to the invoking user. Under sudo, $(id -u) is root and a plain
# chown is a silent no-op; sudo injects SUDO_UID/SUDO_GID carrying the
# original user, so use them when present.
if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${OUT_DIR}" "${OUT_DIR}/${OUT_NAME}"
else
    chown "$(id -u):$(id -g)" "${OUT_DIR}" "${OUT_DIR}/${OUT_NAME}"
fi

# Clean the throwaway live image before it fills the rootful store
sudo podman rmi "${LIVE_TAG}" || true

echo "ISO built: ${OUT_DIR}/${OUT_NAME}"