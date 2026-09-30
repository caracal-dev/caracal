#!/usr/bin/env bash
# Generates the full Flatpak ref list (apps + runtime/locale dependency
# closure) that the installer ISO bakes in for offline installs.
#
# jasonn3/build-container-installer takes FLATPAK_REMOTE_REFS_DIR pointing at
# a directory of files listing refs; Anaconda then installs those refs from
# the ISO itself (file:///flatpak/repo) during installation, with no network
# on the target machine. Runtimes must be listed explicitly — the ISO bundler
# only pulls the commits of the refs given to it — so this script installs
# the app refs and dumps every deployed ref (the full closure) rather than
# maintaining a hand-written runtime list.
#
# Runs INSIDE a throwaway container of the Caracal image being released (it
# already has flatpak, ostree, and the flathub remote from
# /etc/flatpak/remotes.d). Modeled on Bazzite's pre-titanoboa
# just_scripts/build-iso-installer-main.sh.
#
# Usage: generate-flatpak-refs.sh <refs-file> <output-file>
#   <refs-file>   file with full flathub refs to bundle, one per line
#                 (e.g. app/io.github.kolunmi.Bazaar/x86_64/stable)
#   <output-file> where the flattened ref list is written

set -euo pipefail

REFS_FILE="${1:?usage: generate-flatpak-refs.sh <refs-file> <output-file>}"
OUT_FILE="${2:?usage: generate-flatpak-refs.sh <refs-file> <output-file>}"

mapfile -t refs < <(grep -v '^\s*#' "${REFS_FILE}" | grep -v '^\s*$' || true)

if [[ ${#refs[@]} -eq 0 ]]; then
  echo "generate-flatpak-refs: no refs in ${REFS_FILE}; writing empty list." >&2
  : >"${OUT_FILE}"
  exit 0
fi

echo "generate-flatpak-refs: installing ${#refs[@]} ref(s) to collect the dependency closure..." >&2

# Fresh container: make sure the system installation directory exists
# before flatpak touches it.
mkdir -p /var/lib/flatpak

# languages has no effect on which refs deploy (Locale commits deploy
# regardless); the ISO-side Locale filter below handles ISO size.
flatpak config --system --set languages "*"

# The flathub remote comes from /etc/flatpak/remotes.d in the image; the
# first flatpak invocation imports it. Wrap the install in a couple of
# retries for flaky CI-side connectivity; each attempt resumes the partial
# ostree pull instead of restarting.
install_ok=0
for attempt in 1 2 3; do
  if flatpak install --system --noninteractive -y "${refs[@]}"; then
    install_ok=1
    break
  fi
  echo "generate-flatpak-refs: install attempt ${attempt}/3 failed, retrying..." >&2
  sleep 30
done

if [[ "$install_ok" -ne 1 ]]; then
  echo "generate-flatpak-refs: failed to install refs after 3 attempts" >&2
  exit 1
fi

# Deployed refs live under deploy/<ref>; flatten to the plain ref form that
# the ISO bundler (and Anaconda's local-remote install) expects.
# Locale refs are omitted from the ISO on purpose: their commits bundle
# every language (~770 MB for the two platform runtimes), which dominates
# the ISO size. flatpak installs tolerate the missing related ref, so
# offline installs work in English and flatpak-preinstall pulls the
# Locale refs on the first online boot.
ostree refs --repo=/var/lib/flatpak/repo \
  | grep '^deploy/' \
  | grep -v 'org\.freedesktop\.Platform\.openh264' \
  | grep -v '\.Locale/' \
  | sed 's/^deploy\///g' \
  >"${OUT_FILE}"

# Sanity check: every requested ref must have made it into the bundle.
for ref in "${refs[@]}"; do
  if ! grep -qFx "${ref}" "${OUT_FILE}"; then
    echo "generate-flatpak-refs: ${ref} missing from generated ref list" >&2
    exit 1
  fi
done

echo "generate-flatpak-refs: wrote $(wc -l <"${OUT_FILE}") refs to ${OUT_FILE}" >&2
