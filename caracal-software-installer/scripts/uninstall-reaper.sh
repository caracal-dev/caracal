#!/usr/bin/env bash
set -euo pipefail

rm -rf /opt/REAPER
rm -f /usr/local/share/applications/cockos-reaper.desktop
rm -f /usr/local/share/pixmaps/reaper.png
rm -f /usr/local/share/icons/hicolor/256x256/apps/cockos-reaper.png
rm -f /usr/local/share/icons/hicolor/256x256/apps/reaper.png

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo "REAPER removed."
