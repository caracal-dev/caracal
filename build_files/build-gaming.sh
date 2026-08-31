#!/bin/bash
# Caracal Gaming build script
#
# Lightweight overlay for Bazzite-based gaming images. Bazzite already ships
# the kernel, NVIDIA drivers, Steam, Lutris, MangoHud, and the rest of the
# gaming stack — this script only layers Caracal branding and runtime files.

set -ouex pipefail

IMAGE_NAME="${IMAGE_NAME:-caracal-gaming}"

# ── System files ─────────────────────────────────────────────────────────────
# Deploy Caracal's shared system files (branding, just recipes, motd, etc.)
# but skip Caracal-specific setup/installer launchers that conflict with
# Bazzite's own first-run flow.
rsync -rvKlO \
  --exclude='/etc/hostname' \
  --exclude='/usr/bin/caracal-setup' \
  --exclude='/usr/lib/caracal-setup/***' \
  --exclude='/usr/share/caracal-setup/***' \
  --exclude='/usr/share/applications/caracal-setup.desktop' \
  --exclude='/usr/bin/caracal-software-installer' \
  --exclude='/usr/lib/caracal-software-installer/***' \
  --exclude='/usr/share/caracal-software-installer/***' \
  --exclude='/usr/share/applications/caracal-software-installer.desktop' \
  /ctx/system_files/shared/ /

echo "${IMAGE_NAME}" >/etc/hostname

# ── Variant branding ─────────────────────────────────────────────────────────
gaming_variant="Gaming"
gaming_variant_id="caracal-gaming"
if [[ "${IMAGE_NAME}" == *nvidia* ]]; then
  gaming_variant="Gaming NVIDIA"
  gaming_variant_id="caracal-gaming-nvidia"
fi

for kcm_about in \
  /etc/xdg/kcm-about-distrorc \
  /usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc; do
  if [[ -f "${kcm_about}" ]]; then
    sed -i "s/^Variant=.*/Variant=${gaming_variant}/" "${kcm_about}"
  fi
done

if grep -q '^VARIANT=' /usr/lib/os-release; then
  sed -i "s|^VARIANT=.*|VARIANT=\"Caracal OS ${gaming_variant}\"|" /usr/lib/os-release
else
  printf 'VARIANT="Caracal OS %s"\n' "${gaming_variant}" >>/usr/lib/os-release
fi
if grep -q '^VARIANT_ID=' /usr/lib/os-release; then
  sed -i "s|^VARIANT_ID=.*|VARIANT_ID=${gaming_variant_id}|" /usr/lib/os-release
else
  printf 'VARIANT_ID=%s\n' "${gaming_variant_id}" >>/usr/lib/os-release
fi

# ── Branding ─────────────────────────────────────────────────────────────────
bash /ctx/scripts/branding.sh

# ── Cleanup ──────────────────────────────────────────────────────────────────
rm -rf /usr/etc
