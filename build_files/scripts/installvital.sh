#!/usr/bin/env bash
set -euo pipefail

readonly VITAL_REPO_DIR="${1:-/ctx/vital-synth}"
readonly VITAL_DEB="${VITAL_REPO_DIR}/VitalInstaller.deb"
readonly VITAL_DESKTOP="${VITAL_REPO_DIR}/vital.desktop"
readonly VITAL_ICON="${VITAL_REPO_DIR}/vital.png"

if [[ ! -f "${VITAL_DEB}" ]]; then
    echo "Vital installer not found at ${VITAL_DEB}; skipping Vital install."
    exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

dpkg-deb -x "${VITAL_DEB}" "${workdir}/rootfs"
cp -a "${workdir}/rootfs/." /

if [[ -f "${VITAL_DESKTOP}" ]]; then
    install -Dm644 "${VITAL_DESKTOP}" "/usr/share/applications/vital.desktop"
fi

if [[ -f "${VITAL_ICON}" ]]; then
    install -Dm644 "${VITAL_ICON}" "/usr/share/pixmaps/vital.png"
fi

if [[ -x "/opt/Vital/Vital" ]]; then
    install -d "/usr/local/bin"
    ln -sf "/opt/Vital/Vital" "/usr/local/bin/Vital"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi

echo "Vital installed from ${VITAL_DEB}"
