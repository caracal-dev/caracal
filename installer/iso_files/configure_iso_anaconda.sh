#!/usr/bin/env bash
# Wires Anaconda for the Caracal installer ISO live environment.
#
# Adapted from get-aurora-dev/iso (Aurora), Apache-2.0.
#
# The install is offline: the payload image was pulled into the live
# environment as an OCI layout by build.sh, and Anaconda deploys it from
# there via ostreecontainer.
set -eoux pipefail

IMAGE_REF="${BASE_IMAGE%%:*}"
IMAGE_TAG="${BASE_IMAGE##*:}"

sed -i 's/ANACONDA_PRODUCTVERSION=.*/ANACONDA_PRODUCTVERSION=""/' /usr/{,s}bin/liveinst || true

# Anaconda profile, detected via ID=fedora + VARIANT_ID=caracal-os
# (both set by build_files/scripts/branding.sh).
mkdir -p /etc/anaconda/profile.d
tee /etc/anaconda/profile.d/caracal.conf <<'EOF'
# Anaconda configuration file for Caracal OS

[Profile]
profile_id = caracal

[Profile Detection]
os_id = fedora
os_variant_id = caracal-os

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[User Interface]
webui_web_engine = slitherer
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
    UserSpoke
hidden_webui_pages =
    root-password
    network
    anaconda-screen-accounts
EOF

# Installer icon in the live desktop (window class matches the WebUI window)
desktop-file-edit \
    --set-key=Icon --set-value=/usr/share/icons/hicolor/scalable/apps/distributor-logo.svg \
    --set-key=StartupWMClass --set-value=slitherer \
    /usr/share/applications/liveinst.desktop || true

# Interactive Kickstart: deploy the baked OCI layout (offline)
tee -a /usr/share/anaconda/interactive-defaults.ks <<EOF
ostreecontainer --url=/usr/lib/caracal/install:latest --transport=oci --no-signature-verification
%include /usr/share/anaconda/post-scripts/install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/install-flatpaks.ks
%include /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks
EOF

# Post-install: move the installed system onto the published registry tag.
# No signature policy is enforced here — Caracal images are cosign-signed
# but the image does not ship a containers/policy.json to verify against
# (Aurora does; re-add --enforce-container-sigpolicy when we do).
# Best-effort: an offline install keeps the baked image and the update
# happens on the first online boot instead.
tee /usr/share/anaconda/post-scripts/install-configure-upgrade.ks <<EOF
%post
bootc switch --mutate-in-place --transport registry ${IMAGE_REF}:${IMAGE_TAG} || true
%end
EOF

# Post-install: carry the preinstalled Flatpaks (apps + runtimes, minus the
# pruned Locale/openh264 refs) from the live environment into the deployed
# system's /var. Stopping var-lib-flatpak.mount reveals the real repo
# (live-session user changes go to the overlay upperdir and are discarded).
tee /usr/share/anaconda/post-scripts/install-flatpaks.ks <<'EOF'
%post --erroronfail --nochroot
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
systemctl stop var-lib-flatpak.mount
rsync -aAXUHKP /var/lib/flatpak "$target"
sync
%end
EOF

# Post-install: queue MOK enrollment for the ublue akmods signing key so
# Secure Boot systems boot the OGC kernel and load the pre-signed modules
# without manual mokutil steps (see README "Secure Boot"). The key ships in
# the image, so this needs no network.
tee /usr/share/anaconda/post-scripts/secureboot-enroll-key.ks <<'EOF'
%post --erroronfail --nochroot
set -oue pipefail

readonly ENROLLMENT_PASSWORD="universalblue"
readonly SECUREBOOT_KEY="/etc/pki/akmods/certs/akmods-ublue.der"

if [[ ! -d "/sys/firmware/efi" ]]; then
    echo "EFI mode not detected. Skipping key enrollment."
    exit 0
fi

if [[ ! -f "$SECUREBOOT_KEY" ]]; then
    echo "Secure boot key not provided: $SECUREBOOT_KEY"
    exit 0
fi

SYS_ID="$(cat /sys/devices/virtual/dmi/id/product_name)"
if [[ ":Jupiter:Galileo:" =~ ":$SYS_ID:" ]]; then
    echo "Steam Deck hardware detected. Skipping key enrollment."
    exit 0
fi

mokutil --timeout -1 || :
echo -e "$ENROLLMENT_PASSWORD\n$ENROLLMENT_PASSWORD" | mokutil --import "$SECUREBOOT_KEY" || :
%end
EOF