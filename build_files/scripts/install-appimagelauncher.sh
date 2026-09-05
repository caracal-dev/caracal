#!/usr/bin/env bash
set -euo pipefail

source /usr/share/caracal/version-pins

readonly APPIMAGELAUNCHER_RPM="${APPIMAGELAUNCHER_RPM}"
readonly APPIMAGELAUNCHER_URL="${APPIMAGELAUNCHER_URL}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${APPIMAGELAUNCHER_RPM}" "${APPIMAGELAUNCHER_URL}"

# AppImageLauncher's RPM contains a self-contained AppDir under /opt. Installing
# that RPM through dnf/rpm fails in the ostree build root because /opt is a
# symlink into /var/opt. Extract the payload directly instead.
if [[ -L /opt ]]; then
  install -d "$(readlink -f /opt)"
else
  install -d /opt
fi

(
  cd "${workdir}"
  rpm2cpio "${workdir}/${APPIMAGELAUNCHER_RPM}" | cpio -idm --quiet --make-directories --no-absolute-filenames
)

if [[ -d "${workdir}/opt" ]]; then
  rm -rf /opt/appimagelauncher.AppDir
  cp -a "${workdir}/opt/." /opt/
fi

if [[ -d "${workdir}/usr" ]]; then
  cp -a "${workdir}/usr/." /usr/
fi

if [[ ! -x /opt/appimagelauncher.AppDir/usr/bin/ail-cli ]]; then
  echo "CRITICAL ERROR: AppImageLauncher AppDir payload is missing after install." >&2
  exit 1
fi

if [[ ! -x /usr/bin/ail-cli ]]; then
  echo "CRITICAL ERROR: AppImageLauncher ail-cli wrapper is missing after install." >&2
  exit 1
fi
