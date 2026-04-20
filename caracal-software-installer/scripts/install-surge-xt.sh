#!/usr/bin/env bash
set -euo pipefail

readonly SURGE_XT_VERSION="1.3.4"
readonly SURGE_XT_RPM="surge-xt-x86_64-${SURGE_XT_VERSION}.rpm"
readonly SURGE_XT_URL="https://github.com/surge-synthesizer/releases-xt/releases/download/${SURGE_XT_VERSION}/${SURGE_XT_RPM}"

workdir="$(mktemp -d)"
extract_root="${workdir}/root"
trap 'rm -rf "${workdir}"' EXIT

copy_tree() {
    local source_dir="$1"
    local dest_dir="$2"

    if [[ ! -d "${source_dir}" ]]; then
        return
    fi

    mkdir -p "${dest_dir}"
    cp -a "${source_dir}/." "${dest_dir}/"
}

echo "Downloading Surge XT ${SURGE_XT_VERSION}..."
curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${SURGE_XT_RPM}" "${SURGE_XT_URL}"
mkdir -p "${extract_root}"

if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "${workdir}/${SURGE_XT_RPM}" -C "${extract_root}"
elif command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
    (
        cd "${extract_root}"
        rpm2cpio "${workdir}/${SURGE_XT_RPM}" | cpio -idm --quiet
    )
else
    echo "Need bsdtar or the rpm2cpio+cpio toolchain to unpack the Surge XT RPM." >&2
    exit 1
fi

copy_tree "${extract_root}/usr/bin" "/usr/local/bin"
copy_tree "${extract_root}/usr/lib64" "/usr/local/lib64"
copy_tree "${extract_root}/usr/lib" "/usr/local/lib"
copy_tree "${extract_root}/usr/share" "/usr/local/share"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor >/dev/null 2>&1 || true
fi

echo "Surge XT installed into /usr/local"
