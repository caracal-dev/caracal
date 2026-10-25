#!/usr/bin/env bash
# Overlay-mount /var/lib/flatpak in the live environment so only the
# preinstalled Flatpak set transfers to the installed system: user
# install/remove actions in the live session land in the tmpfs-backed
# upperdir and are discarded, while install-flatpaks.ks copies the real
# underlying repo after stopping this mount.
#
# https://github.com/get-aurora-dev/iso/issues/72
set -eoux pipefail

cat > /usr/lib/systemd/system/var-lib-flatpak.mount <<'EOF'
[Unit]
Description=tmpfs so only the preinstalled flatpaks are transferred to the installed system
Conflicts=umount.target

[Mount]
Type=overlay
What=overlay
Where=/var/lib/flatpak
Options=lowerdir=/var/lib/flatpak,upperdir=/run/overlay/flatpak,workdir=/run/overlay/flatpak.work
[Install]
WantedBy=local-fs.target
EOF

cat > /usr/lib/tmpfiles.d/caracal-iso-flatpak.conf <<'EOF'
d /run/overlay/flatpak 0755 - - -
d /run/overlay/flatpak.work 0755 - - -
EOF

systemctl enable var-lib-flatpak.mount