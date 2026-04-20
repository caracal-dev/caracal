#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-plugin-archive.sh" \
    "tal-noisemaker" \
    "TAL-Noisemaker" \
    "https://tal-software.com/downloads/plugins/TAL-NoiseMaker_64_linux.zip" \
    "TAL-NoiseMaker" \
    "clap,vst,vst3,lv2"
