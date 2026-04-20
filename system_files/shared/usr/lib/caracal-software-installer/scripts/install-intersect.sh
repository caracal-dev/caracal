#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-plugin-archive.sh" \
  "intersect" \
  "INTERSECT" \
  "https://github.com/tucktuckg00se/INTERSECT/releases/download/v0.10.8/INTERSECT-v0.10.8-Linux-x64.zip" \
  "INTERSECT" \
  "vst3"
