#!/usr/bin/env bash
set -euo pipefail

find "${HOME}/.clap" -maxdepth 1 \( -iname '*loopino*.clap' -o -iname '*loopino*' \) -exec rm -rf {} + 2>/dev/null || true
find "${HOME}/.vst" -maxdepth 1 \( -iname '*loopino*.so' -o -iname '*loopino*' \) -exec rm -rf {} + 2>/dev/null || true
find "${HOME}/.vst2" -maxdepth 1 \( -iname '*loopino*.so' -o -iname '*loopino*' \) -exec rm -rf {} + 2>/dev/null || true

echo "Loopino removed from user plugin directories."
