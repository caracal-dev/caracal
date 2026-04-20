#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/install-warmplace-zip-app.sh" \
    "virtual-ans" \
    "Virtual ANS" \
    "3.0.4" \
    "https://warmplace.ru/soft/ans/virtual_ans-3.0.4.zip" \
    "virtual_ans" \
    "virtual-ans" \
    "virtual-ans" \
    "Spectral drawing synthesizer"
