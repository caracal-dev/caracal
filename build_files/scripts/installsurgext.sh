#!/usr/bin/env bash
set -euo pipefail

readonly SURGE_XT_VERSION="1.3.4"
readonly SURGE_XT_RPM="surge-xt-x86_64-${SURGE_XT_VERSION}.rpm"
readonly SURGE_XT_URL="https://github.com/surge-synthesizer/releases-xt/releases/download/${SURGE_XT_VERSION}/${SURGE_XT_RPM}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${SURGE_XT_RPM}" "${SURGE_XT_URL}"
dnf5 install -y --nogpgcheck "${workdir}/${SURGE_XT_RPM}"
