#!/usr/bin/env bash
# Installs Bitwig Studio to /opt/bitwig-studio (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-bitwig (runs as root via sudo).
# Requires: dpkg (pre-installed in image), libbsd, bzip2-libs
set -euo pipefail

BITWIG_DEB="/tmp/bitwig.deb"
BITWIG_EXTRACT_DIR="/tmp/bitwig-extract"

cleanup() {
    rm -rf "${BITWIG_EXTRACT_DIR}" "${BITWIG_DEB}"
}

trap cleanup EXIT

echo "Downloading Bitwig Studio..."
curl -L -o "${BITWIG_DEB}" "https://www.bitwig.com/dl/?id=419&os=installer_linux"

mkdir -p "${BITWIG_EXTRACT_DIR}"
dpkg-deb -x "${BITWIG_DEB}" "${BITWIG_EXTRACT_DIR}"

# Install to /opt (persists across image updates on atomic Fedora)
rm -rf /opt/bitwig-studio
mv "${BITWIG_EXTRACT_DIR}/opt/bitwig-studio" /opt/bitwig-studio

# Copy remaining files (desktop entry, icons, MIME types, etc.) to /usr/local
mkdir -p /usr/local/bin /usr/local/share
if [ -d "${BITWIG_EXTRACT_DIR}/usr/bin" ]; then
    cp -a "${BITWIG_EXTRACT_DIR}/usr/bin/." /usr/local/bin/
fi
if [ -d "${BITWIG_EXTRACT_DIR}/usr/share" ]; then
    cp -a "${BITWIG_EXTRACT_DIR}/usr/share/." /usr/local/share/
fi

# Symlink binary into PATH
ln -sf /opt/bitwig-studio/bitwig-studio /usr/local/bin/bitwig-studio

# Adjust desktop files for the relocated prefix when present.
if [ -f /usr/local/share/applications/bitwig-studio.desktop ]; then
    sed -i \
        -e 's|Exec=/usr/bin/bitwig-studio|Exec=/usr/local/bin/bitwig-studio|g' \
        -e 's|Icon=/usr/share/|Icon=/usr/local/share/|g' \
        /usr/local/share/applications/bitwig-studio.desktop
fi


# Bitwig needs libbz2.so.1.0 but Fedora ships libbz2.so.1
ln -sf /usr/lib64/libbz2.so.1 /usr/lib64/libbz2.so.1.0

echo "Bitwig Studio installed to /opt/bitwig-studio"
