#!/usr/bin/env bash
set -euo pipefail

readonly APPIMAGELAUNCHER_RPM="appimagelauncher_3.0.0-beta-2-gha287.96cb937_x86_64.rpm"
readonly APPIMAGELAUNCHER_URL="https://github.com/TheAssassin/AppImageLauncher/releases/download/v3.0.0-beta-3/${APPIMAGELAUNCHER_RPM}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${APPIMAGELAUNCHER_RPM}" "${APPIMAGELAUNCHER_URL}"

dnf -y install "${workdir}/${APPIMAGELAUNCHER_RPM}"

install -d /opt
(
  cd "${workdir}"
  rpm2cpio "${workdir}/${APPIMAGELAUNCHER_RPM}" | cpio -idm --quiet --make-directories --no-absolute-filenames
)

if [[ -d "${workdir}/opt" ]]; then
  cp -a "${workdir}/opt/." /opt/
fi

if [[ ! -x /opt/appimagelauncher.AppDir/usr/bin/ail-cli ]]; then
  echo "CRITICAL ERROR: AppImageLauncher AppDir payload is missing after install." >&2
  exit 1
fi
