#!/usr/bin/bash
# Fetch Betterfox waterfox/user.js at image build time (not vendored in-tree).
#
# user.js is upstream-owned (yokoffing/Betterfox, waterfox/ variant). Caracal
# appends its own prefs from waterfox-caracal.overrides.js so they survive
# upstream churn. Result is <target-dir>/user.js with a provenance header.
#
# Pin: BETTERFOX_COMMIT must be a commit reachable from Betterfox main. Bump
# it to pull a newer Betterfox; the full SHA lands in the header of the
# shipped user.js for provenance.
#
# Usage: fetch-waterfox-userjs.sh <target-dir>

set -euo pipefail

BETTERFOX_URL="https://github.com/yokoffing/Betterfox"
BETTERFOX_COMMIT="${BETTERFOX_COMMIT:-067172a4b0dc90e78e5b8b94d9abfe6430c6a7be}"

if [[ $# -ne 1 ]]; then
  echo "ERROR: usage: $0 <target-dir>" >&2
  exit 2
fi
TARGET_DIR="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v git >/dev/null 2>&1; then
  dnf5 -y install git
fi

WORKTREE="$(mktemp -d /tmp/caracal-betterfox.XXXXXX)"
trap 'rm -rf "${WORKTREE}"' EXIT

git clone --quiet --depth 1 "${BETTERFOX_URL}" "${WORKTREE}"
git -C "${WORKTREE}" fetch --quiet --depth 1 origin "${BETTERFOX_COMMIT}"
git -C "${WORKTREE}" -c advice.detachedHead=false checkout --quiet "${BETTERFOX_COMMIT}"

mkdir -p "${TARGET_DIR}"
{
  printf '// Caracal: %s waterfox/user.js @ %s (generated at image build time)\n' \
    "${BETTERFOX_URL}" "${BETTERFOX_COMMIT}"
  cat "${WORKTREE}/waterfox/user.js"
  printf '\n'
  cat "${SCRIPT_DIR}/waterfox-caracal.overrides.js"
  printf '\n'
} >"${TARGET_DIR}/user.js"

echo "fetch-waterfox-userjs: wrote ${TARGET_DIR}/user.js (@${BETTERFOX_COMMIT})"