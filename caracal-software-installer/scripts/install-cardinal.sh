#!/usr/bin/env bash
set -euo pipefail

readonly CARDINAL_VERSION="26.02"
readonly CARDINAL_ARCHIVE="Cardinal-linux-x86_64-${CARDINAL_VERSION}.tar.gz"
readonly CARDINAL_URL="https://github.com/DISTRHO/Cardinal/releases/download/${CARDINAL_VERSION}/${CARDINAL_ARCHIVE}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

install_dir_bundle() {
    local source_dir="$1"
    local dest_root="$2"
    local bundle_name
    bundle_name="$(basename "${source_dir}")"

    mkdir -p "${dest_root}"
    rm -rf "${dest_root}/${bundle_name}"
    cp -a "${source_dir}" "${dest_root}/"
}

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${CARDINAL_ARCHIVE}" "${CARDINAL_URL}"
tar xzf "${workdir}/${CARDINAL_ARCHIVE}" -C "${workdir}"

extract_dir="$(find "${workdir}" -mindepth 1 -maxdepth 2 -type f -name 'CardinalNative' -printf '%h\n' | head -n 1)"
if [[ -z "${extract_dir}" || ! -d "${extract_dir}" ]]; then
    echo "Cardinal archive did not contain the expected Cardinal files" >&2
    exit 1
fi

install -Dm755 "${extract_dir}/CardinalNative" "/usr/local/bin/Cardinal"
install -Dm755 "${extract_dir}/CardinalJACK" "/usr/local/bin/CardinalJACK"

install_dir_bundle "${extract_dir}/Cardinal.vst" "/usr/local/lib64/vst"
install_dir_bundle "${extract_dir}/Cardinal.vst3" "/usr/local/lib64/vst3"
install_dir_bundle "${extract_dir}/CardinalFX.vst3" "/usr/local/lib64/vst3"
install_dir_bundle "${extract_dir}/CardinalSynth.vst3" "/usr/local/lib64/vst3"
install_dir_bundle "${extract_dir}/Cardinal.lv2" "/usr/local/lib64/lv2"
install_dir_bundle "${extract_dir}/CardinalFX.lv2" "/usr/local/lib64/lv2"
install_dir_bundle "${extract_dir}/CardinalSynth.lv2" "/usr/local/lib64/lv2"
install_dir_bundle "${extract_dir}/CardinalMini.lv2" "/usr/local/lib64/lv2"
install_dir_bundle "${extract_dir}/Cardinal.clap" "/usr/local/lib64/clap"

echo "Cardinal installed into /usr/local/bin and /usr/local/lib64"
