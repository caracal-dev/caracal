#!/usr/bin/env bash
set -euo pipefail

find /usr/local/bin -maxdepth 1 \( -iname 'surge*' -o -iname 'Surge*' \) -delete 2>/dev/null || true
find /usr/local/lib64 -maxdepth 3 \( -iname '*surge*' -o -iname '*Surge*' \) -exec rm -rf {} + 2>/dev/null || true
find /usr/local/lib -maxdepth 3 \( -iname '*surge*' -o -iname '*Surge*' \) -exec rm -rf {} + 2>/dev/null || true
find /usr/local/share -maxdepth 4 \( -iname '*surge*' -o -iname '*Surge*' \) -exec rm -rf {} + 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor >/dev/null 2>&1 || true
fi

echo "Surge XT removed."
