#!/usr/bin/env bash
set -euo pipefail

# Install appimagetool from AppImageKit for building AppImages inside Caracal
readonly APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
readonly APPIMAGETOOL_BIN="/usr/local/bin/appimagetool"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

echo "Downloading appimagetool..."
curl -fL --retry 3 --retry-delay 2 -o "${workdir}/appimagetool-x86_64.AppImage" "${APPIMAGETOOL_URL}"

install -d /usr/local/bin
install -m 755 "${workdir}/appimagetool-x86_64.AppImage" "${APPIMAGETOOL_BIN}"

if [[ ! -x "${APPIMAGETOOL_BIN}" ]]; then
  echo "CRITICAL ERROR: appimagetool is missing after install." >&2
  exit 1
fi

echo "appimagetool installed successfully at ${APPIMAGETOOL_BIN}"