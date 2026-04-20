#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-plugin-archive.sh" \
  "mix-locker" \
  "Mix Locker" \
  "https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/MixLockerLinux.zip" \
  "Mix Locker" \
  "vst3,lv2" \
  "MixLockerData" \
  "MixLockerData"
