#!/usr/bin/env bash
# Replaces the stock Fedora kernel with the CachyOS LTO kernel.
# CachyOS LTO kernel is compiled with Link-Time Optimization and ships
# sched-ext (SCX) support, giving lower latency for realtime audio workloads.
#
# Adapted from the Zena project (https://github.com/zena-linux/zena),
# specifically build-scripts/modules/base/kernel.sh.
# Zena is licensed under the Apache License 2.0.
# Credit to the Zena contributors: https://github.com/zena-linux/zena/graphs/contributors

set -ouex pipefail

shopt -s nullglob

KERNEL_PACKAGES=(
  kernel-cachyos-lto
  kernel-cachyos-lto-core
  kernel-cachyos-lto-devel-matched
  kernel-cachyos-lto-modules
)

# Disable kernel-install hooks so they don't trigger inside the container
# build environment. The initramfs will be generated explicitly below.
pushd /usr/lib/kernel/install.d
printf '%s\n' '#!/bin/sh' 'exit 0' >05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' >50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

# Erase stock Fedora kernel RPMs from the package database
for pkg in kernel kernel-core kernel-modules kernel-modules-core; do
  rpm --erase "$pkg" --nodeps || true
done

# Remove ALL existing kernel module directories. The original script used
# `head -n1` which only removed the first entry — on Kinoite's base image
# there are typically two kernel versions, leaving an orphaned module
# directory that confuses rpm-ostree/bootc at deploy time.
for KVER in $(ls /usr/lib/modules 2>/dev/null); do
  rm -rf "/usr/lib/modules/$KVER"
done

dnf5 -y install "${KERNEL_PACKAGES[@]}"

dnf5 versionlock add "${KERNEL_PACKAGES[@]}" || true

# Identify the newly installed CachyOS kernel version
NEW_KVER=$(ls /usr/lib/modules | head -n1)

# Ensure vmlinuz is at the path expected by rpm-ostree and bootc for boot
# entry generation. Some COPR kernel RPMs only install vmlinuz to /boot and
# not to /usr/lib/modules/<kver>/vmlinuz; copy it over if missing.
if [ ! -f "/usr/lib/modules/${NEW_KVER}/vmlinuz" ]; then
  if [ -f "/boot/vmlinuz-${NEW_KVER}" ]; then
    cp "/boot/vmlinuz-${NEW_KVER}" "/usr/lib/modules/${NEW_KVER}/vmlinuz"
  else
    echo "ERROR: vmlinuz not found for kernel ${NEW_KVER}" >&2
    exit 1
  fi
fi

# Generate the initramfs inside the container image so that rpm-ostree and
# bootc can use it directly at deploy time. Without this step, Kinoite boots
# with no initramfs and hits a dracut emergency shell (the "wall of errors").
#   --no-hostonly : include all drivers, not just the CI build host's hardware
#   --add ostree  : include the ostree dracut module for atomic deployments
dracut \
  --reproducible \
  --no-hostonly \
  --add "ostree" \
  --force \
  "/usr/lib/modules/${NEW_KVER}/initrd" \
  "${NEW_KVER}"

# Atomic images manage /boot via the bootloader layer; clear any kernel
# files the RPM dropped there.
rm -rf /boot/*
