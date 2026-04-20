#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <app-id> <wrapper-name> <desktop-id>" >&2
    exit 1
fi

app_id="$1"
wrapper_name="$2"
desktop_id="$3"

rm -rf "/opt/caracal/warmplace/${app_id}"
rm -f "/usr/local/bin/${wrapper_name}"
rm -f "/usr/local/share/applications/${desktop_id}.desktop"
rm -f "/usr/local/share/icons/hicolor/scalable/apps/${desktop_id}.svg"
rm -f "/usr/local/share/icons/hicolor/256x256/apps/${desktop_id}.png"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor >/dev/null 2>&1 || true
fi

echo "${app_id} removed."
