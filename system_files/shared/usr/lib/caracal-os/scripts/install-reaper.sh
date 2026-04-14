#!/usr/bin/env bash
# Installs REAPER to /opt/REAPER (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-reaper (runs as root via sudo).
set -euo pipefail

REAPER_VERSION="765"
REAPER_ARCHIVE="/tmp/reaper.tar.xz"
REAPER_EXTRACT_DIR="/tmp/reaper_linux_x86_64"
DESKTOP_TARGET="/usr/local/share/applications/cockos-reaper.desktop"

cleanup() {
    rm -rf "${REAPER_ARCHIVE}" "${REAPER_EXTRACT_DIR}"
}

trap cleanup EXIT

echo "Downloading REAPER ${REAPER_VERSION}..."
curl -L -o "${REAPER_ARCHIVE}" "https://www.reaper.fm/files/7.x/reaper${REAPER_VERSION}_linux_x86_64.tar.xz"
tar -xJf "${REAPER_ARCHIVE}" -C /tmp

cd "${REAPER_EXTRACT_DIR}"
./install-reaper.sh --install /opt --integrate-desktop

mkdir -p /usr/local/share/applications

# The upstream installer is inconsistent about where it writes the desktop file.
# Promote it to a system-wide location when present, otherwise write a fallback.
desktop_source=""
for candidate in \
    "/root/.local/share/applications/cockos-reaper.desktop" \
    "/root/Desktop/cockos-reaper.desktop" \
    "${REAPER_EXTRACT_DIR}/cockos-reaper.desktop"
do
    if [ -f "${candidate}" ]; then
        desktop_source="${candidate}"
        break
    fi
done

if [ -n "${desktop_source}" ]; then
    install -m644 "${desktop_source}" "${DESKTOP_TARGET}"
else
    cat > "${DESKTOP_TARGET}" <<'EOF'
[Desktop Entry]
Name=REAPER
Comment=Digital Audio Workstation
Exec=/opt/REAPER/reaper %F
Icon=reaper
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Recorder;Mixer;
MimeType=application/x-reaper-project;
StartupWMClass=REAPER
EOF
fi

# Fix installer-generated paths when present.
sed -i \
    -e 's|/root/opt/REAPER|/opt/REAPER|g' \
    -e 's|Exec=/root/opt/REAPER/|Exec=/opt/REAPER/|g' \
    "${DESKTOP_TARGET}"

echo "REAPER installed to /opt/REAPER"
echo "Desktop entry written to /usr/local/share/applications/"
