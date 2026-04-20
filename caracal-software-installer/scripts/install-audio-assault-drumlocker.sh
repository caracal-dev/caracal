#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-plugin-archive.sh" \
  "drum-locker" \
  "Drum Locker" \
  "https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/DrumLockerLinux.zip" \
  "Drum Locker" \
  "vst3,lv2" \
  "DrumLockerData" \
  "DrumLockerData"
