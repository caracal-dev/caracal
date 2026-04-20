#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-warmplace-zip-app.sh" \
    "sunvox" \
    "SunVox" \
    "2.1.4d" \
    "https://warmplace.ru/soft/sunvox/sunvox-2.1.4d.zip" \
    "sunvox" \
    "sunvox" \
    "sunvox" \
    "Modular tracker and synthesizer"
