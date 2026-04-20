#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/uninstall-plugin-archive.sh" "TAL-NoiseMaker" "clap,vst,vst3,lv2"
