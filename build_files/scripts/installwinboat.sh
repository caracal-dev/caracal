#!/usr/bin/env bash
set -euo pipefail

readonly WINBOAT_VERSION="0.9.0"
readonly WINBOAT_TAG="v${WINBOAT_VERSION}"
readonly WINBOAT_RPM="winboat-${WINBOAT_VERSION}-x86_64.rpm"
readonly WINBOAT_URL="https://github.com/TibixDev/winboat/releases/download/${WINBOAT_TAG}/${WINBOAT_RPM}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${WINBOAT_RPM}" "${WINBOAT_URL}"

# Upstream WinBoat's RPM currently fails to install cleanly in our bootc build
# environment when rpm tries to create /opt/winboat. Extract the payload
# directly instead so the image still contains the installed application files.
install -d /opt
cd "${workdir}"
rpm2cpio "${workdir}/${WINBOAT_RPM}" | cpio -idm --quiet --make-directories --no-absolute-filenames

if [[ -d "${workdir}/opt" ]]; then
    cp -a "${workdir}/opt/." /opt/
fi

if [[ -d "${workdir}/usr" ]]; then
    cp -a "${workdir}/usr/." /usr/
fi
