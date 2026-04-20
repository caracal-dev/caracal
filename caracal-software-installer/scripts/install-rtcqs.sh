#!/usr/bin/env bash
# Installs rtcqs and rtcqs_gui into a user-local Python virtualenv.
set -euo pipefail

target_user="${SUDO_USER:-${USER}}"
target_home="$(getent passwd "${target_user}" | cut -d: -f6)"

if [[ -z "${target_home}" || ! -d "${target_home}" ]]; then
    echo "Could not resolve home directory for ${target_user}" >&2
    exit 1
fi

install_root="${target_home}/.local/share/caracal-os/rtcqs"
venv_dir="${install_root}/venv"
bin_dir="${target_home}/.local/bin"
app_dir="${target_home}/.local/share/applications"
desktop_file="${app_dir}/rtcqs-gui.desktop"

mkdir -p "${install_root}" "${bin_dir}" "${app_dir}"

if [[ ! -d "${venv_dir}" ]]; then
    python3 -m venv "${venv_dir}"
fi

"${venv_dir}/bin/pip" install --upgrade pip rtcqs

cat > "${bin_dir}/rtcqs" <<EOF
#!/usr/bin/env bash
exec "${venv_dir}/bin/rtcqs" "\$@"
EOF

cat > "${bin_dir}/rtcqs_gui" <<EOF
#!/usr/bin/env bash
exec "${venv_dir}/bin/rtcqs_gui" "\$@"
EOF

chmod 755 "${bin_dir}/rtcqs" "${bin_dir}/rtcqs_gui"

cat > "${desktop_file}" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=RTCQS GUI
GenericName=Realtime Audio Diagnostics
Comment=Launch the rtcqs graphical interface
Exec=${bin_dir}/rtcqs_gui
TryExec=${bin_dir}/rtcqs_gui
Icon=utilities-system-monitor
Terminal=false
StartupNotify=true
Categories=AudioVideo;Audio;System;
Keywords=audio;realtime;latency;pipewire;jack;
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${app_dir}" >/dev/null 2>&1 || true
fi

if ! "${venv_dir}/bin/python" -c 'import tkinter' >/dev/null 2>&1; then
    echo "rtcqs installed, but tkinter is missing so rtcqs_gui will not start." >&2
    echo "Install the distro tkinter package (Caracal image package: python3-tkinter)." >&2
fi

echo "rtcqs installed to ${venv_dir}"
echo "Commands:"
echo "  ${bin_dir}/rtcqs"
echo "  ${bin_dir}/rtcqs_gui"
