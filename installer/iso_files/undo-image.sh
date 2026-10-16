#!/usr/bin/env bash
# Services that belong to the installed system, not the live environment:
# they would mutate first-boot state in the live session or fight livesys.
# Adapted from get-aurora-dev/iso undo-image.sh. Credit github.com/get-aurora-dev
set -eoux pipefail

systemctl disable flatpak-preinstall.service flatpak-preinstall.timer || true
systemctl disable brew-setup.service || true
systemctl disable caracal-cpu-performance.service || true
systemctl disable caracal-wine-execmod.service || true
systemctl disable cpupower.service || true
systemctl disable libvirtd.service || true
# livesys provides live-session autologin and user setup
systemctl disable caracal-autologin.service || true
systemctl --global disable caracal-setup-launch.service || true
systemctl --global disable caracal-user-setup.service || true
systemctl --global disable caracal-user-post-setup.service || true
systemctl --global disable caracal-waterfox-config.path || true
