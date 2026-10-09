#!/usr/bin/env bash
# Builds the Caracal installer ISO live environment inside a throwaway
# container of a released Caracal image.
#
# Adapted from get-aurora-dev/iso (Aurora), Apache-2.0.
#
# Expects: BASE_IMAGE (payload to install), BUNDLE_FLATPAKS, LIVESYS_SESSION
# from the Containerfile env, and /src/iso_files/ populated by the COPY.
set -exo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# /root is a symlink; livesys and sysusers write through it
mkdir -p "$(realpath /root)"

# bwrap tries to write /proc/sys/user/max_user_namespaces which is mounted
# read-only inside the build sandbox, so remount it rw
mount -o remount,rw /proc/sys

# --- Offline Flatpaks --------------------------------------------------------
# Only app refs belong in installer/iso-flatpaks; flatpak resolves the
# runtime dependency closure during install. Locale refs bundle every
# language (~770 MB of raw commits) and openh264 is already provided by the
# system stack — both are pruned here and return on the first online boot
# via flatpak-preinstall.service.
if [[ "${BUNDLE_FLATPAKS:-true}" == "true" && -s "${SCRIPT_DIR}/flatpaks.list" ]]; then
  echo "Installing offline Flatpaks..."
  grep -v '^\s*#' "${SCRIPT_DIR}/flatpaks.list" |
    grep -v '^\s*$' |
    xargs -r flatpak install -y --system --noninteractive
  # Prune via ostree refs — authoritative view of what actually deployed
  # (flatpak list is unreliable for related refs in build containers).
  mapfile -t prune_refs < <(ostree refs --repo=/var/lib/flatpak/repo |
    grep '^deploy/' |
    grep -E '\.Locale/|\.openh264' |
    sed 's/^deploy\///' || true)
  if ((${#prune_refs[@]})); then
    flatpak uninstall --system --noninteractive --force-remove "${prune_refs[@]}"
  fi
fi

# --- Payload image (offline install source) ----------------------------------
# Pull the image the ISO installs into /usr/lib/containers/storage so it is
# captured by the squashfs and does not exhaust RAM in the booted live
# environment. At runtime podman finds it again through the additional image
# store configured in /usr/share/containers/storage.conf of the base image.
mkdir -p /etc/containers
cat >/etc/containers/storage.conf <<'EOF'
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/usr/lib/containers/storage"
EOF

podman pull "${BASE_IMAGE:?BASE_IMAGE build-arg is required}"

rm -f /etc/containers/storage.conf

# --- Installer environment ----------------------------------------------------
dnf install -y \
  dracut-live \
  livesys-scripts \
  anaconda-live \
  anaconda-webui \
  rsync \
  desktop-file-utils \
  libblockdev-btrfs \
  libblockdev-lvm \
  libblockdev-dm

# Live boot kernel: swap the OGC kernel for the stock Fedora one so the ISO
# boots under Secure Boot. The image's kernel is signed only with the ublue
# MOK keys (akmods public_key.der), which shim does not trust — Secure Boot
# machines fail at kernel load ("bad shim signature"). The stock Fedora
# kernel carries Fedora CA + Microsoft signatures, so the shim → grub →
# kernel chain verifies. The installed payload keeps the OGC kernel; only
# the live environment's boot kernel is swapped. Credit to https://github.com/ublue-os/bazzite
# for the titanoboa preinitramfs hook.
kernel_pkgs=(
  kernel kernel-core kernel-devel kernel-devel-matched
  kernel-modules kernel-modules-core kernel-modules-extra
  kernel-modules-akmods kernel-common kernel-tools kernel-tools-libs
  kernel-rt kernel-rt-core kernel-rt-modules kernel-rt-modules-extra
)
dnf -y versionlock delete "${kernel_pkgs[@]}" || :
dnf --setopt=protect_running_kernel=False -y remove "${kernel_pkgs[@]}" || :
rm -rf /usr/lib/modules/*
dnf -y --repo fedora,updates --setopt=tsflags=noscripts install kernel kernel-core
kernel=$(find /usr/lib/modules -maxdepth 1 -type d -printf '%P\n' | grep . | head -1)
depmod "$kernel"

# Live initramfs: add dmsquash-live so the squashfs ISO rootfs boots,
# replacing the ostree-only initramfs produced by the image build. The
# bootc-isos contract consumes /usr/lib/modules/<kver>/initramfs.img.
kernel=$(find /usr/lib/modules -maxdepth 1 -type d -printf '%P\n' | grep . | head -1)
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
  --add "dmsquash-live dmsquash-live-autooverlay" \
  "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# Live session (kde for the Kinoite-based flavors, gnome for Silverblue)
sed -i "s/^livesys_session=.*/livesys_session=${LIVESYS_SESSION:-kde}/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# Autologin for the live session: livesys-kde only uncomments template lines
# in the display-manager config, and plasmalogin 6.7.5 ships its config
# without #User=/#Session= templates, so the live session would otherwise
# stop at the greeter. Pre-write the [Autologin] section — the boot-time sed
# in livesys-kde only touches commented lines and leaves this intact. When
# the config file does not exist (sddm systems), livesys writes it itself.
if [[ -f /etc/plasmalogin.conf ]]; then
  cat >>/etc/plasmalogin.conf <<'EOF'

[Autologin]
User=liveuser
Session=plasma.desktop
EOF
fi

# ISO-specific hooks
bash "${SCRIPT_DIR}/undo-image.sh"
bash "${SCRIPT_DIR}/flatpak-mount-workaround.sh"
bash "${SCRIPT_DIR}/configure_iso_anaconda.sh"

# --- UEFI boot chain (bootc-isos contract) ------------------------------------
# image-builder (the ISO assembler) needs the standalone GRUB CD boot EFI
# binary and grub modules.
_arch=$(uname -m)
if [[ $_arch == "x86_64" ]]; then
  dnf install -y grub2-efi-x64-cdboot
elif [[ $_arch == "aarch64" ]]; then
  dnf install -y grub2-efi-aa64-modules
fi

# The assembler expects shim/grub EFI binaries in /boot/efi/EFI/$VENDOR; the
# image keeps them under /usr/lib/efi/<vendor>/<arch>/EFI.
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/

# Fallback entry for firmware that only boots \EFI\BOOT\BOOTX64.EFI
if [[ $_arch == "x86_64" ]]; then
  cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi
elif [[ $_arch == "aarch64" ]]; then
  cp -v /boot/efi/EFI/fedora/grubaa64.efi /boot/efi/EFI/BOOT/fbaa64.efi
fi

# Deterministic live boot (no host timezone leak)
rm -f /etc/localtime
systemd-firstboot --timezone UTC

# Larger tmpfs for /var/tmp: Anaconda needs more scratch space than the
# default tmpfs sizing in the live environment
mkdir -p /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# bootc-isos contract: ISO menu config consumed by build_iso.sh
mkdir -p /usr/lib/bootc-image-builder
cp "${SCRIPT_DIR}/iso.yaml" /usr/lib/bootc-image-builder/iso.yaml

dnf clean all
