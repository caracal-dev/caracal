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
FALLBACK_ICON_NAME="reaper"
REAPER_VST_PATH="/usr/lib64/vst;/usr/lib64/vst3;/usr/local/lib64/vst;/usr/local/lib64/vst3;~/.vst;~/.vst3"
REAPER_LV2_PATH="/usr/lib64/lv2;/usr/local/lib64/lv2;~/.lv2"
REAPER_CLAP_PATH="/usr/lib64/clap;/usr/local/lib64/clap;~/.clap;%CLAP_PATH%"

set_reaper_ini_value() {
    local ini_file="$1"
    local key="$2"
    local value="$3"

    if grep -q "^${key}=" "${ini_file}"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${ini_file}"
    else
        printf '%s=%s\n' "${key}" "${value}" >> "${ini_file}"
    fi
}

configure_reaper_plugin_paths() {
    local target_user="${SUDO_USER:-}"
    local target_home=""
    local config_dir=""
    local ini_file=""

    if [[ -z "${target_user}" || "${target_user}" == "root" ]]; then
        echo "Skipping REAPER user config seeding because SUDO_USER is not set."
        return
    fi

    target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
    if [[ -z "${target_home}" || ! -d "${target_home}" ]]; then
        echo "Could not resolve home directory for ${target_user}; skipping REAPER user config seeding."
        return
    fi

    config_dir="${target_home}/.config/REAPER"
    ini_file="${config_dir}/reaper.ini"

    install -d -m755 -o "${target_user}" -g "${target_user}" "${config_dir}"
    touch "${ini_file}"
    chown "${target_user}:${target_user}" "${ini_file}"

    set_reaper_ini_value "${ini_file}" "vstpath64" "${REAPER_VST_PATH}"
    set_reaper_ini_value "${ini_file}" "lv2path" "${REAPER_LV2_PATH}"
    set_reaper_ini_value "${ini_file}" "clappath" "${REAPER_CLAP_PATH}"
}

cleanup() {
    rm -rf "${REAPER_ARCHIVE}" "${REAPER_EXTRACT_DIR}"
}

trap cleanup EXIT

echo "Downloading REAPER ${REAPER_VERSION}..."
curl -L -o "${REAPER_ARCHIVE}" "https://www.reaper.fm/files/7.x/reaper${REAPER_VERSION}_linux_x86_64.tar.xz"
tar -xJf "${REAPER_ARCHIVE}" -C /tmp

cd "${REAPER_EXTRACT_DIR}"

# The upstream desktop integration writes through xdg-* helpers into system
# paths that are not writable on Atomic systems. Install the app only, then
# manage the desktop file and icon locations ourselves below.
./install-reaper.sh --install /opt

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
else
    if grep -q '^Icon=' "${DESKTOP_TARGET}"; then
        sed -i "s|^Icon=.*|Icon=${FALLBACK_ICON_NAME}|" "${DESKTOP_TARGET}"
    else
        printf 'Icon=%s\n' "${FALLBACK_ICON_NAME}" >> "${DESKTOP_TARGET}"
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

configure_reaper_plugin_paths

echo "REAPER installed to /opt/REAPER"
echo "Desktop entry written to /usr/local/share/applications/"
