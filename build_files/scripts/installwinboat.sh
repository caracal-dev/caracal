#!/usr/bin/env bash
set -euo pipefail

readonly WINBOAT_VERSION="0.9.0"
readonly WINBOAT_TAG="v${WINBOAT_VERSION}"
readonly WINBOAT_RPM="winboat-${WINBOAT_VERSION}-x86_64.rpm"
readonly WINBOAT_URL="https://github.com/TibixDev/winboat/releases/download/${WINBOAT_TAG}/${WINBOAT_RPM}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${WINBOAT_RPM}" "${WINBOAT_URL}"
dnf5 install -y --nogpgcheck "${workdir}/${WINBOAT_RPM}"
