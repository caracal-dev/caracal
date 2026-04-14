#!/usr/bin/env bash
# Installs REAPER to /opt/REAPER (writable on atomic Fedora via /var/opt).
# Intended to be called from ujust install-reaper (runs as root via sudo).
set -euo pipefail

REAPER_VERSION="765"
REAPER_ARCHIVE="/tmp/reaper.tar.xz"
REAPER_EXTRACT_DIR="/tmp/reaper_linux_x86_64"
DESKTOP_TARGET="/usr/local/share/applications/cockos-reaper.desktop"
ICON_THEME_DIR="/usr/local/share/icons/hicolor/256x256/apps"
ICON_TARGET_DIR="/usr/local/share/pixmaps"
ICON_TARGET="${ICON_THEME_DIR}/cockos-reaper.png"
ICON_COMPAT_TARGET="${ICON_THEME_DIR}/reaper.png"
ICON_PIXMAP_TARGET="${ICON_TARGET_DIR}/reaper.png"

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
mkdir -p "${ICON_THEME_DIR}"
mkdir -p "${ICON_TARGET_DIR}"

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

# Promote a usable icon into /usr/local so menu/taskbar entries resolve on immutable systems.
icon_source=""
for candidate in \
    "/root/.local/share/icons/hicolor/256x256/apps/reaper.png" \
    "/root/.local/share/icons/hicolor/128x128/apps/reaper.png" \
    "/root/.local/share/pixmaps/reaper.png" \
    "/opt/REAPER/reaper.png" \
    "${REAPER_EXTRACT_DIR}/reaper.png"
do
    if [ -f "${candidate}" ]; then
        icon_source="${candidate}"
        break
    fi
done

if [ -n "${icon_source}" ]; then
    install -m644 "${icon_source}" "${ICON_TARGET}"
    install -m644 "${icon_source}" "${ICON_COMPAT_TARGET}"
    install -m644 "${icon_source}" "${ICON_PIXMAP_TARGET}"
fi

# Fix installer-generated paths when present.
sed -i \
    -e 's|/root/opt/REAPER|/opt/REAPER|g' \
    -e 's|Exec=/root/opt/REAPER/|Exec=/opt/REAPER/|g' \
    "${DESKTOP_TARGET}"

if [ -f "${ICON_TARGET}" ]; then
    if grep -q '^Icon=' "${DESKTOP_TARGET}"; then
        sed -i 's|^Icon=.*|Icon=cockos-reaper|' "${DESKTOP_TARGET}"
    else
        printf 'Icon=cockos-reaper\n' >> "${DESKTOP_TARGET}"
    fi
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor || true
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo "REAPER installed to /opt/REAPER"
echo "Desktop entry written to /usr/local/share/applications/"
