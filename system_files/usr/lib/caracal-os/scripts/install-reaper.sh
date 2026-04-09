#!/usr/bin/env bash
# Installs REAPER to /opt/REAPER (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-reaper (runs as root via sudo).
set -euo pipefail

REAPER_VERSION="765"

echo "Downloading REAPER ${REAPER_VERSION}..."
curl -L -o /tmp/reaper.tar.xz "https://www.reaper.fm/files/7.x/reaper${REAPER_VERSION}_linux_x86_64.tar.xz"
tar -xJf /tmp/reaper.tar.xz -C /tmp

cd /tmp/reaper_linux_x86_64
./install-reaper.sh --install /opt --integrate-desktop

# The installer drops the .desktop file under the running user's home (~root).
# Move it to a system-wide location with corrected paths.
mkdir -p /usr/local/share/applications
if [ -f "/root/.local/share/applications/cockos-reaper.desktop" ]; then
    cp /root/.local/share/applications/cockos-reaper.desktop \
       /usr/local/share/applications/cockos-reaper.desktop
fi
# Fix any /root/opt references to /opt
sed -i 's|/root/opt/REAPER|/opt/REAPER|g' /usr/local/share/applications/cockos-reaper.desktop

rm -rf /tmp/reaper*
echo "REAPER installed to /opt/REAPER"
echo "Desktop entry written to /usr/local/share/applications/"
