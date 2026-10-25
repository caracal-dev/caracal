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
# Newer Caracal images ship the policy+key in /etc, but an already-installed
# system cannot update to receive it. This script writes the same setup to
# /etc, which is what bootc reads on the running system.
#
# Run once, as root, on the affected machine:
#
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/caracal-dev/caracal/main/build_files/signing/install-sigpolicy.sh)"
#
# Then update as normal:  sudo bootc upgrade
#
# Note: the policy default is `reject` scoped to ghcr.io/caracal-dev/* (and the
# tumillanino dev fork, which shares the same signing key). Image updates (and
# pulls of Caracal images) verify against the published cosign key; pulls of
# unrelated registries must be allowed explicitly in /etc/containers/policy.json.
#
# If `bootc upgrade` still refuses after this script, the refusal is signature
# verification, not the old insecureAcceptAnything policy — the image you are
# updating to must have been signed with the current key (any release pushed
# after this fix landed qualifies). Try again after the next release.
set -euo pipefail

# Defaults to the production repo; set CARACAL_RAW_URL to test against another
# fork/branch (e.g. a dev fork before the fix is merged upstream).
RAW_URL="${CARACAL_RAW_URL:-https://raw.githubusercontent.com/caracal-dev/caracal/main}"
PKI_DIR=/etc/pki/containers
REGISTRIES_DIR=/etc/containers/registries.d
POLICY_JSON=/etc/containers/policy.json

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

# If the running image's configured upgrade ref is a Caracal repo not covered
# by the fetched policy, refuse to proceed: the policy default is `reject`, so
# a mismatched scope would silently brick updates. All known Caracal hosts are
# covered; this only guards against a CARACAL_RAW_URL override pointing at an
# unrelated fork. Override with CARACAL_POLICY_SCOPE=skip.
if [[ "${CARACAL_POLICY_SCOPE:-}" != "skip" ]]; then
  deployed_ref=$(command -v bootc >/dev/null 2>&1 \
    && bootc status --format json 2>/dev/null \
    | awk -F'"' '/"image":/{seen++} seen==2{print $4; exit}') || true
  case "${deployed_ref:-}" in
    ghcr.io/caracal-dev/*|ghcr.io/tumillanino/*|"")
      ;;
    *)
      echo "Deployed image ref '${deployed_ref}' is not covered by the Caracal" >&2
      echo "policy (expected ghcr.io/caracal-dev/*). Refusing to install." >&2
      exit 1
      ;;
  esac
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
install -m 0644 "${tmp}/policy.json" "${POLICY_JSON}"
install -m 0644 "${tmp}/caracal.yaml" "${REGISTRIES_DIR}/caracal.yaml"

echo "Installed Caracal image signature verification policy:"
echo "  - key:      ${PKI_DIR}/caracal.pub"
echo "  - policy:   ${POLICY_JSON} (default reject; scoped to ghcr.io/caracal-dev/*)"
echo "  - sigstore: ${REGISTRIES_DIR}/caracal.yaml"
echo
echo "Next step: sudo bootc upgrade"
