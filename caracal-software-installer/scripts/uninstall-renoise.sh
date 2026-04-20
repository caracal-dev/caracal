#!/usr/bin/env bash
set -euo pipefail

rm -rf /opt/renoise
rm -f /usr/local/bin/renoise
rm -f /usr/local/share/applications/renoise.desktop
rm -f /usr/local/share/icons/hicolor/48x48/apps/renoise.png
rm -f /usr/local/share/icons/hicolor/64x64/apps/renoise.png
rm -f /usr/local/share/icons/hicolor/128x128/apps/renoise.png
rm -f /usr/local/share/mime/packages/renoise.xml
rm -f /usr/local/share/man/man1/renoise.1.gz
rm -f /usr/local/share/man/man5/renoise-pattern-effects.5.gz

echo "Renoise removed."
