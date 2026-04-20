#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-plugin-archive.sh" \
  "amp-locker" \
  "Amp Locker" \
  "https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/AmpLockerLinux.zip" \
  "Amp Locker" \
  "vst3,lv2" \
  "AmpLockerData" \
  "AmpLockerData"
