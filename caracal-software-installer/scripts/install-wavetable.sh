#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-plugin-archive.sh" \
  "wavetable" \
  "Wavetable_Linux" \
  "https://socalabs.com/files/get.php?id=Wavetable_Linux.zip" \
  "Wavetable" \
  "vst,vst3,lv2"
