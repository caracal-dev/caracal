#!/usr/bin/env bash
set -euo pipefail

readonly LOOPINO_REPO_URL="${LOOPINO_REPO_URL:-https://github.com/brummer10/Loopino.git}"

workdir="$(mktemp -d)"
repo_dir="${workdir}/Loopino"

cleanup() {
    rm -rf "${workdir}"
}

require_command() {
    local command_name="$1"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Required command not found: ${command_name}" >&2
        exit 1
    fi
}

trap cleanup EXIT

require_command git
require_command make

echo "Cloning Loopino sources..."
git clone "${LOOPINO_REPO_URL}" "${repo_dir}"
cd "${repo_dir}"
git submodule update --init --recursive

mkdir -p "${HOME}/.clap" "${HOME}/.vst"

echo "Building Loopino CLAP..."
make clap
make install

make clean >/dev/null 2>&1 || true

echo "Building Loopino VST2..."
make vst2
make install

echo "Loopino installed into:"
echo "  ${HOME}/.clap"
echo "  ${HOME}/.vst"
