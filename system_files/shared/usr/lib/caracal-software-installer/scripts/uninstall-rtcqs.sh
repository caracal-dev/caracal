#!/usr/bin/env bash
set -euo pipefail

target_user="${SUDO_USER:-${USER}}"
target_home="$(getent passwd "${target_user}" | cut -d: -f6)"

if [[ -z "${target_home}" || ! -d "${target_home}" ]]; then
    echo "Could not resolve home directory for ${target_user}" >&2
    exit 1
fi

rm -rf "${target_home}/.local/share/caracal-os/rtcqs"
rm -f "${target_home}/.local/bin/rtcqs"
rm -f "${target_home}/.local/bin/rtcqs_gui"
rm -f "${target_home}/.local/share/applications/rtcqs-gui.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${target_home}/.local/share/applications" >/dev/null 2>&1 || true
fi

echo "rtcqs removed from ${target_home}"
