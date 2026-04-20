#!/usr/bin/env bash
set -euo pipefail

rm -rf /opt/bitwig-studio
rm -f /usr/local/bin/bitwig-studio
rm -f /usr/local/lib64/libbz2.so.1.0
rm -f /usr/local/share/applications/bitwig-studio.desktop
rm -rf /usr/local/share/bitwig-studio

find /usr/local/share/icons -path '*/apps/bitwig-studio.*' -delete 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications
fi

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/local/share/mime
fi

echo "Bitwig Studio removed."
