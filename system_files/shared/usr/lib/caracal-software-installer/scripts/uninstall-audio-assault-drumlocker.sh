#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/uninstall-plugin-archive.sh" "Drum Locker" "vst3,lv2" "DrumLockerData"
