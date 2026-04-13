#!/usr/bin/env bash
# Installs Renoise (demo) to /opt/renoise (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-renoise (runs as root via sudo).
set -euo pipefail

RENOISE_VERSION="3.5.4"
EXTRACT_DIR="/tmp/Renoise_3_5_4_Demo_Linux_x86_64"

echo "Downloading Renoise ${RENOISE_VERSION} Demo..."
curl -L -o /tmp/renoise.tar.gz \
    "https://files.renoise.com/demo/Renoise_3_5_4_Demo_Linux_x86_64.tar.gz"
tar xf /tmp/renoise.tar.gz -C /tmp

# Install to /opt so it persists across image updates
mkdir -p /opt/renoise
cp -r "${EXTRACT_DIR}/Resources" /opt/renoise/
install -m755 "${EXTRACT_DIR}/renoise" /opt/renoise/renoise

# Wrapper so 'renoise' is in PATH
mkdir -p /usr/local/bin
cat > /usr/local/bin/renoise << 'EOF'
#!/bin/bash
exec /opt/renoise/renoise "$@"
EOF
chmod 755 /usr/local/bin/renoise

# Desktop entry, icons, MIME types, man pages
mkdir -p /usr/local/share/applications \
         /usr/local/share/icons/hicolor/{48x48,64x64,128x128}/apps \
         /usr/local/share/mime/packages \
         /usr/local/share/man/man1 \
         /usr/local/share/man/man5

install -m644 "${EXTRACT_DIR}/Installer/renoise.desktop"         /usr/local/share/applications/renoise.desktop
install -m644 "${EXTRACT_DIR}/Installer/renoise-48.png"          /usr/local/share/icons/hicolor/48x48/apps/renoise.png
install -m644 "${EXTRACT_DIR}/Installer/renoise-64.png"          /usr/local/share/icons/hicolor/64x64/apps/renoise.png
install -m644 "${EXTRACT_DIR}/Installer/renoise-128.png"         /usr/local/share/icons/hicolor/128x128/apps/renoise.png
install -m644 "${EXTRACT_DIR}/Installer/renoise.xml"             /usr/local/share/mime/packages/renoise.xml
install -m644 "${EXTRACT_DIR}/Installer/renoise.1.gz"            /usr/local/share/man/man1/renoise.1.gz
install -m644 "${EXTRACT_DIR}/Installer/renoise-pattern-effects.5.gz" \
              /usr/local/share/man/man5/renoise-pattern-effects.5.gz

# Fix the Exec path in the .desktop file (installer points to system paths)
sed -i 's|Exec=renoise|Exec=/opt/renoise/renoise|g' /usr/local/share/applications/renoise.desktop

rm -rf /tmp/renoise.tar.gz "${EXTRACT_DIR}"
echo "Renoise installed to /opt/renoise"
echo "Run 'renoise' to launch, or purchase a license at renoise.com to unlock full functionality."
