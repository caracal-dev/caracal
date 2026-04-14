#!/usr/bin/env bash
# Installs Bitwig Studio to /opt/bitwig-studio (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-bitwig (runs as root via sudo).
# Requires: dpkg (pre-installed in image), libbsd, bzip2-libs
set -euo pipefail

BITWIG_DEB="/tmp/bitwig.deb"
BITWIG_EXTRACT_DIR="/tmp/bitwig-extract"
BITWIG_LIB_DIR="/usr/local/lib64"
BITWIG_WRAPPER="/usr/local/bin/bitwig-studio"
BITWIG_DESKTOP_FILE="/usr/local/share/applications/bitwig-studio.desktop"

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
mkdir -p /usr/local/bin /usr/local/share "${BITWIG_LIB_DIR}"
if [ -d "${BITWIG_EXTRACT_DIR}/usr/share" ]; then
    cp -a "${BITWIG_EXTRACT_DIR}/usr/share/." /usr/local/share/
fi

# Bitwig needs libbz2.so.1.0 but Fedora exposes libbz2.so.1 under /usr/lib64.
# Provide the compatibility soname from a writable prefix and point the launcher at it.
ln -sf /usr/lib64/libbz2.so.1 "${BITWIG_LIB_DIR}/libbz2.so.1.0"

cat > "${BITWIG_WRAPPER}" <<'EOF'
#!/usr/bin/env bash
export LD_LIBRARY_PATH="/usr/local/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
exec /opt/bitwig-studio/bitwig-studio "$@"
EOF
chmod 755 "${BITWIG_WRAPPER}"

# Adjust desktop files for the relocated prefix when present.
if [ -f "${BITWIG_DESKTOP_FILE}" ]; then
    sed -i \
        -e 's|/usr/bin/bitwig-studio|/usr/local/bin/bitwig-studio|g' \
        -e 's|Icon=/usr/share/|Icon=/usr/local/share/|g' \
        "${BITWIG_DESKTOP_FILE}"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications
fi

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database /usr/local/share/mime
fi

echo "Bitwig Studio installed to /opt/bitwig-studio"
