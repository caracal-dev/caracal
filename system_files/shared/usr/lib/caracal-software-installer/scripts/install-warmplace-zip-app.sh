#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 8 ]]; then
    echo "Usage: $0 <app-id> <display-name> <version> <url> <executable-name> <wrapper-name> <desktop-id> <comment>" >&2
    exit 1
fi

app_id="$1"
display_name="$2"
version="$3"
url="$4"
executable_name="$5"
wrapper_name="$6"
desktop_id="$7"
comment="$8"

workdir="$(mktemp -d)"
archive_path="${workdir}/${app_id}.zip"
extract_dir="${workdir}/extract"
install_root="/opt/caracal/warmplace/${app_id}"
install_dir="${install_root}/${version}"
current_link="${install_root}/current"
wrapper_path="/usr/local/bin/${wrapper_name}"
desktop_path="/usr/local/share/applications/${desktop_id}.desktop"
icon_base="/usr/local/share/icons/hicolor"

cleanup() {
    rm -rf "${workdir}"
}

extract_zip() {
    local archive="$1"
    local destination="$2"

    mkdir -p "${destination}"
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "${archive}" -d "${destination}"
        return
    fi

    if command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "${archive}" -C "${destination}"
        return
    fi

    if command -v 7z >/dev/null 2>&1; then
        7z x -y "-o${destination}" "${archive}" >/dev/null
        return
    fi

    echo "Need one of: unzip, bsdtar, or 7z to unpack ZIP archives." >&2
    exit 1
}

find_launcher() {
    local root="$1"
    local exec_name="$2"
    local launcher=""
    local arch=""
    local -a arch_dirs=()

    arch="$(uname -m 2>/dev/null || true)"
    case "${arch}" in
        x86_64|amd64)
            arch_dirs=("linux_x86_64" "linux_x86")
            ;;
        aarch64|arm64)
            arch_dirs=("linux_arm64" "linux_arm")
            ;;
        armv7l|armv7*|armhf)
            arch_dirs=("linux_arm")
            ;;
        i386|i486|i586|i686)
            arch_dirs=("linux_x86")
            ;;
    esac

    for arch_dir in "${arch_dirs[@]}"; do
        launcher="$(find "${root}" -type f -path "*/${arch_dir}/${exec_name}" | head -n 1)"
        if [[ -n "${launcher}" ]]; then
            printf '%s\n' "${launcher}"
            return
        fi
    done

    launcher="$(find "${root}" -type f -name 'START_LINUX*' | head -n 1)"
    if [[ -n "${launcher}" ]]; then
        printf '%s\n' "${launcher}"
        return
    fi

    launcher="$(find "${root}" -type f -path '*/linux_*/*' -name "${exec_name}" | head -n 1)"
    if [[ -n "${launcher}" ]]; then
        printf '%s\n' "${launcher}"
        return
    fi

    launcher="$(find "${root}" -type f -name "${exec_name}" | head -n 1)"
    if [[ -n "${launcher}" ]]; then
        printf '%s\n' "${launcher}"
        return
    fi

    return 1
}

copy_icon() {
    local source_root="$1"
    local target_id="$2"
    local icon_source=""

    icon_source="$(find "${source_root}" -type f \( -iname "${target_id}.png" -o -iname "${target_id}.svg" -o -iname '*.png' -o -iname '*.svg' \) | head -n 1 || true)"
    if [[ -z "${icon_source}" ]]; then
        return
    fi

    if [[ "${icon_source}" == *.svg ]]; then
        mkdir -p "${icon_base}/scalable/apps"
        install -m644 "${icon_source}" "${icon_base}/scalable/apps/${target_id}.svg"
        return
    fi

    mkdir -p "${icon_base}/256x256/apps"
    install -m644 "${icon_source}" "${icon_base}/256x256/apps/${target_id}.png"
}

trap cleanup EXIT

echo "Downloading ${display_name} ${version}..."
curl -fL --retry 3 --retry-delay 2 -o "${archive_path}" "${url}"

extract_zip "${archive_path}" "${extract_dir}"

payload_dir="${extract_dir}"
shopt -s nullglob
entries=("${extract_dir}"/*)
shopt -u nullglob
if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" ]]; then
    payload_dir="${entries[0]}"
fi

mkdir -p "${install_root}"
rm -rf "${install_dir}"
mkdir -p "${install_dir}"
cp -a "${payload_dir}/." "${install_dir}/"
ln -sfn "${install_dir}" "${current_link}"

launcher_path="$(find_launcher "${install_dir}" "${executable_name}")"
chmod +x "${launcher_path}" || true
launcher_rel="${launcher_path#${install_dir}/}"

mkdir -p /usr/local/bin /usr/local/share/applications
cat > "${wrapper_path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
APP_HOME="${current_link}"
cd "\${APP_HOME}"
exec "\${APP_HOME}/${launcher_rel}" "\$@"
EOF
chmod 755 "${wrapper_path}"

copy_icon "${install_dir}" "${desktop_id}"

icon_name="${desktop_id}"
if [[ ! -f "${icon_base}/scalable/apps/${desktop_id}.svg" && ! -f "${icon_base}/256x256/apps/${desktop_id}.png" ]]; then
    icon_name="multimedia-player"
fi

cat > "${desktop_path}" <<EOF
[Desktop Entry]
Name=${display_name}
Comment=${comment}
Exec=${wrapper_path}
Icon=${icon_name}
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;
StartupNotify=true
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/local/share/icons/hicolor >/dev/null 2>&1 || true
fi

echo "${display_name} installed to ${install_dir}"
echo "Launcher: ${wrapper_path}"
