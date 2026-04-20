#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${script_dir}/uninstall-warmplace-zip-app.sh" "sunvox" "sunvox" "sunvox"
