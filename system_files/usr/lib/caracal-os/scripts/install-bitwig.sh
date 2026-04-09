#!/usr/bin/env bash
# Installs Bitwig Studio to /opt/bitwig-studio (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-bitwig (runs as root via sudo).
# Requires: dpkg (pre-installed in image), libbsd, bzip2-libs
set -euo pipefail

echo "Downloading Bitwig Studio..."
curl -L -o /tmp/bitwig.deb "https://www.bitwig.com/dl/?id=419&os=installer_linux"

mkdir -p /tmp/bitwig-extract
dpkg-deb -x /tmp/bitwig.deb /tmp/bitwig-extract

# Install to /opt (persists across image updates on atomic Fedora)
mv /tmp/bitwig-extract/opt/bitwig-studio /opt/bitwig-studio

# Copy remaining files (icons, MIME types, etc.) to /usr/local
cp -rT /tmp/bitwig-extract/usr /usr/local

# Symlink binary into PATH
ln -sf /opt/bitwig-studio/bitwig-studio /usr/local/bin/bitwig-studio

# Fix paths in .desktop file
if [ -f /usr/local/share/applications/com.bitwig.BitwigStudio.desktop ]; then
    sed -i 's|/opt/bitwig-studio|/opt/bitwig-studio|g' \
        /usr/local/share/applications/com.bitwig.BitwigStudio.desktop
fi

# Bitwig needs libbz2.so.1.0 but Fedora ships libbz2.so.1
ln -sf /usr/lib64/libbz2.so.1 /usr/lib64/libbz2.so.1.0

rm -rf /tmp/bitwig-extract /tmp/bitwig.deb
echo "Bitwig Studio installed to /opt/bitwig-studio"
