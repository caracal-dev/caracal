#!/usr/bin/env bash
set -euo pipefail

readonly DECENT_SAMPLER_VERSION="1.18.1"
readonly DECENT_SAMPLER_ARCHIVE="Decent_Sampler-${DECENT_SAMPLER_VERSION}-Linux-Static-x86_64.tar.gz"
readonly DECENT_SAMPLER_URL="https://cdn.decentsamples.com/production/builds/ds/${DECENT_SAMPLER_VERSION}/${DECENT_SAMPLER_ARCHIVE}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

curl -fL --retry 3 --retry-delay 2 -o "${workdir}/${DECENT_SAMPLER_ARCHIVE}" "${DECENT_SAMPLER_URL}"
tar xzf "${workdir}/${DECENT_SAMPLER_ARCHIVE}" -C "${workdir}"

extract_dir="$(find "${workdir}" -maxdepth 1 -mindepth 1 -type d -name 'Decent_Sampler-*' | head -n 1)"
if [[ -z "${extract_dir}" ]]; then
    echo "Decent Sampler archive did not contain the expected directory layout" >&2
    exit 1
fi

install -Dm755 "${extract_dir}/DecentSampler" "/usr/bin/DecentSampler"
install -Dm755 "${extract_dir}/DecentSampler.so" "/usr/lib64/vst/DecentSampler.so"
mkdir -p "/usr/lib64/vst3"
cp -a "${extract_dir}/DecentSampler.vst3" "/usr/lib64/vst3/"
