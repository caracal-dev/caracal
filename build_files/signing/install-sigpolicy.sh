#!/usr/bin/env bash
# Install Caracal's image signature verification policy on an existing system.
#
# Why this exists: systems installed with the pre-titanoboa Caracal installer
# are deployed with the `ostree-image-signed` transport (signature enforcement
# on), but those images shipped the stock Fedora containers/policy.json with an
# `insecureAcceptAnything` default. bootc refuses to update under that policy:
#
#   error: Upgrading: Preparing import: Fetching manifest: containers-policy.json
#          specifies a default of `insecureAcceptAnything`; refusing usage
#
# Newer Caracal images ship the policy+key in /usr/etc, but an already-installed
# system cannot update to receive it. This script writes the same setup to
# /etc, which is what bootc reads on the running system.
#
# Run once, as root, on the affected machine:
#
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/tumillanino/caracal/main/build_files/signing/install-sigpolicy.sh)"
#
# Then update as normal:  sudo bootc upgrade
#
# Note: the policy default is `reject` scoped to ghcr.io/tumillanino/*. Image
# updates (and pulls of Caracal images) verify against the published cosign
# key; pulls of unrelated registries must be allowed explicitly in
# /etc/containers/policy.json.
set -euo pipefail

RAW_URL="${CARACAL_RAW_URL:-https://raw.githubusercontent.com/tumillanino/caracal/main}"
PKI_DIR=/etc/pki/containers
REGISTRIES_DIR=/etc/containers/registries.d

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

fetch() {
  local url="$1" out="$2" i
  for i in 1 2 3; do
    if curl -fsSL --retry 3 "${url}" -o "${out}"; then
      return 0
    fi
    sleep 2
  done
  echo "Failed to fetch ${url}" >&2
  return 1
}

install -d "${PKI_DIR}" "${REGISTRIES_DIR}"
fetch "${RAW_URL}/cosign.pub" "${tmp}/caracal.pub"
fetch "${RAW_URL}/build_files/signing/containers/policy.json" "${tmp}/policy.json"
fetch "${RAW_URL}/build_files/signing/containers/registries.d/caracal.yaml" "${tmp}/caracal.yaml"

install -m 0644 "${tmp}/caracal.pub" "${PKI_DIR}/caracal.pub"
install -m 0644 "${tmp}/policy.json" /etc/containers/policy.json
install -m 0644 "${tmp}/caracal.yaml" "${REGISTRIES_DIR}/caracal.yaml"

echo "Installed Caracal cosign verification policy."
echo "Next step: sudo bootc upgrade"
