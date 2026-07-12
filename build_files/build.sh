#!/bin/bash
# Caracal OS build script

set -ouex pipefail

SCRIPTS_DIR="/ctx/scripts"

# System files
rsync -rvKlO \
  --exclude='/etc/hostname' \
  --exclude='/usr/bin/caracal-setup' \
  --exclude='/usr/lib/caracal-setup/***' \
  --exclude='/usr/share/caracal-setup/***' \
  --exclude='/usr/share/applications/caracal-setup.desktop' \
  --exclude='/usr/bin/caracal-software-installer' \
  --exclude='/usr/lib/caracal-software-installer/***' \
  --exclude='/usr/share/caracal-software-installer/***' \
  --exclude='/usr/share/applications/caracal-software-installer.desktop' \
  /ctx/system_files/shared/ /
echo "caracal" >/etc/hostname

set_copr_priority() {
  local owner="$1"
  local project="$2"
  local priority="$3"
  local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${owner}:${project}.repo"

  [[ -f "${repo_file}" ]] || return 0

  if grep -q '^priority=' "${repo_file}"; then
    sed -i "s/^priority=.*/priority=${priority}/" "${repo_file}"
  else
    printf 'priority=%s\n' "${priority}" >>"${repo_file}"
  fi
}

validate_wine_stack() {
  echo "Checking for mandatory Wine and Yabridge binaries..."
  rpm -q \
    wine-core.x86_64 \
    wine-common.noarch \
    yabridge.x86_64 \
    winetricks || {
    echo "CRITICAL ERROR: required Wine RPMs are missing!" >&2
    dnf5 list installed "wine*" "yabridge*" "winetricks*" || true
    exit 1
  }

  local wine_found=0
  local wine_bin=""
  local bin
  for bin in /usr/bin/wine /usr/bin/wine64 /usr/sbin/wine /usr/sbin/wine64 /opt/wine-tkg/bin/wine /opt/wine-tkg/bin/wine64; do
    if [[ -x "$bin" ]]; then
      wine_found=1
      wine_bin="$bin"
      echo "Found Wine at $bin"
      break
    fi
  done

  if [[ $wine_found -eq 0 ]]; then
    echo "CRITICAL ERROR: Wine loader not found in expected locations!" >&2
    dnf5 list installed "wine*" || true
    ls -l /usr/bin/wine* /usr/sbin/wine* /opt/wine-tkg/bin/wine* 2>/dev/null || true
    exit 1
  fi

  local wineboot_found=0
  local wineboot_bin=""
  for bin in /usr/bin/wineboot /usr/sbin/wineboot /opt/wine-tkg/bin/wineboot; do
    if [[ -x "$bin" ]]; then
      wineboot_found=1
      wineboot_bin="$bin"
      echo "Found wineboot at $bin"
      break
    fi
  done

  if [[ $wineboot_found -eq 0 ]]; then
    echo "CRITICAL ERROR: wineboot not found!" >&2
    dnf5 list installed "wine*" || true
    ls -l /usr/bin/wine* /usr/sbin/wine* /opt/wine-tkg/bin/wine* 2>/dev/null || true
    exit 1
  fi

  if ! command -v yabridgectl &>/dev/null; then
    echo "CRITICAL ERROR: yabridgectl not found!" >&2
    exit 1
  fi

  local wine_version=""
  wine_version="$("${wine_bin}" --version 2>/dev/null || true)"
  echo "Wine version: ${wine_version:-unknown}"
  if [[ "${wine_version}" != wine-11.8* ]]; then
    echo "CRITICAL ERROR: expected Patrickl's Juce 8 Wine 11.8 stack, got '${wine_version:-unknown}'." >&2
    echo "Wine 11.10 currently fails PE32 WoW64 execution on Caracal; keep the Wine stack pinned to Wine 11.8." >&2
    dnf5 list installed "wine*" "yabridge*" "winetricks*" || true
    exit 1
  fi

  echo "Checking for 32-bit Windows support through Wine WoW64..."
  local wow64_prefix
  wow64_prefix="$(mktemp -d /tmp/caracal-wow64-check.XXXXXX)"
  if ! WINEPREFIX="${wow64_prefix}" WINEDEBUG=-all "${wineboot_bin}" -u; then
    WINEPREFIX="${wow64_prefix}" wineserver -w 2>/dev/null || true
    rm -rf "${wow64_prefix}"
    echo "CRITICAL ERROR: Wine cannot initialize a temporary WoW64 prefix." >&2
    dnf5 list installed "wine*" || true
    exit 1
  fi
  local wine_i386_cmd=""
  for bin in \
    /usr/lib64/wine-wow64/wine/i386-windows/cmd.exe \
    /usr/lib/wine/i386-windows/cmd.exe \
    /usr/lib64/wine/i386-windows/cmd.exe; do
    if [[ -f "$bin" ]]; then
      wine_i386_cmd="$bin"
      break
    fi
  done
  # NOTE: a crashing 32-bit Wine process still exits 0, so we must inspect the
  # actual output of `ver` instead of trusting the exit code (the old check
  # silently passed while every 32-bit installer was failing). This also only
  # reflects the build-time overlay, not the deployed composefs root where the
  # caracal-wine-execmod.service applies the real fix at boot.
  local pe32_output=""
  if [[ -n "${wine_i386_cmd}" ]]; then
    pe32_output="$(WINEPREFIX="${wow64_prefix}" WINEDEBUG=-all "${wine_bin}" "${wine_i386_cmd}" /c ver 2>/dev/null || true)"
  fi
  if [[ -z "${wine_i386_cmd}" ]] || ! grep -qi 'Microsoft Windows' <<<"${pe32_output}"; then
    WINEPREFIX="${wow64_prefix}" wineserver -w 2>/dev/null || true
    rm -rf "${wow64_prefix}"
    echo "WARNING: Wine could not run a PE32 program through WoW64 at build time." >&2
    echo "On the deployed composefs root this is handled by caracal-wine-execmod.service;" >&2
    echo "the build-time overlay can legitimately fail this check, so it is non-fatal." >&2
    dnf5 list installed "wine*" || true
    return 0
  fi
  WINEPREFIX="${wow64_prefix}" wineserver -w 2>/dev/null || true
  rm -rf "${wow64_prefix}"

  echo "Wine and Yabridge validation successful."
}

install_wine_stack() {
  dnf5 -y install --allowerasing "${wine_bridge_packages[@]}"
  dnf5 -y mark user \
    wine \
    wine-core \
    wine-common \
    wine-alsa \
    wine-cms \
    wine-desktop \
    wine-pulseaudio \
    wine-winefonts \
    wine-mono \
    wine-dxvk \
    winetricks \
    yabridge \
    ntsync-autoload \
    pipewire-wineasio ||
    true
}

# Prefer Patrickl's Juce 8/VSTGUI Wine build for Windows audio installers and
# yabridge workflows. It is a new-WoW64 x86_64/noarch stack, so do not require
# Fedora's i686 Wine packages when this repo is active.
if dnf5 -y copr enable patrickl/wine-11.8-vstgui-juce8; then
  set_copr_priority patrickl wine-11.8-vstgui-juce8 80
else
  echo "WARNING: failed to enable patrickl/wine-11.8-vstgui-juce8; falling back to patrickl/wine-tkg-dev." >&2
fi
dnf5 -y copr enable patrickl/wine-tkg-dev
set_copr_priority patrickl wine-tkg-dev 90

# COPR repositories
copr_repos=(
  ycollet/audinux
  teervo/DISTRHO
  ublue-os/packages
  ublue-os/staging
  tumillanino/caracal-packages
)
for copr_repo in "${copr_repos[@]}"; do
  dnf5 -y copr enable "${copr_repo}"
done

dnf -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
bash "${SCRIPTS_DIR}/install-appimagelauncher.sh"
dnf -y install "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

dnf5 -y install caracal-setup caracal-software-installer caracal-audio-controller

# Realtime support
dnf5 -y install realtime-setup

systemctl enable realtime-setup.service
systemctl enable realtime-entsk.service

default_packages_to_remove=(
  zram-generator-defaults
  nano
  vim-minimal
  firefox
  firefox-langpacks
  plasma-discover
  plasma-discover-flatpak
  plasma-discover-kns
  plasma-discover-libs
  plasma-discover-notifier
  plasma-discover-rpm-ostree
)

# Remove unwanted defaults
dnf5 -y remove "${default_packages_to_remove[@]}" || true

dnf5 -y swap fedora-logos generic-logos
rpm --erase --nodeps --nodb generic-logos

# COPR audio packages
wine_bridge_packages=(
  yabridge
  wine-11.8-300.fc44.x86_64
  wine-core-11.8-300.fc44.x86_64
  wine-alsa-11.8-300.fc44.x86_64
  wine-cms-11.8-300.fc44.x86_64
  wine-common-11.8-300.fc44.noarch
  wine-desktop-11.8-300.fc44.noarch
  wine-pulseaudio-11.8-300.fc44.x86_64
  wine-winefonts-11.8-300.fc44.noarch
  winetricks
  wine-mono
  wine-dxvk
  ntsync-autoload
  pipewire-wineasio
)

copr_audio_workflow_packages=(
  vst-DISTRHO-drumsynth.x86_64
  vst-DISTRHO-eqinox.x86_64 vst-DISTRHO-vitalium.x86_64
)

optional_audio_workflow_packages=(
  libcurl-gnutls
)

base_system_packages=(
  zsh
  openssl
  openssh
  ghostty
  7zip
  neovim
  python3-tkinter
  ublue-os-just
  distrobox
  zenity
)

compatibility_tool_packages=(
  alien
  waydroid
  freerdp
  podman-compose
)

hardware_firmware_packages=(
  alsa-firmware
  alsa-sof-firmware
  alsa-tools-firmware
  atheros-firmware
  brcmfmac-firmware
  iwlegacy-firmware
  iwlwifi-dvm-firmware
  iwlwifi-mvm-firmware
  realtek-firmware
  mt7xxx-firmware
  nxpwireless-firmware
  tiwilink-firmware
  midisport-firmware
)

hardware_diagnostic_packages=(
  usbutils
  pciutils
  i2c-tools
  ddcutil
  evtest
)

audio_device_packages=(
  alsa-utils
  alsa-plugins-jack
  a2jmidid
  ffado
  libusb1
  hidapi
  v4l-utils
)

audio_server_packages=(
  pipewire-jack-audio-connection-kit
  jack-audio-connection-kit-dbus
  qjackctl
  pavucontrol
  pipewire-alsa
  pipewire-utils
  helvum
  rtkit
  tuned-profiles-realtime
  wireplumber
  easyeffects
)

media_codec_packages=(
  lame
  flac
  libavcodec-freeworld
  gstreamer1-plugins-bad-freeworld
  gstreamer1-plugins-good
  gstreamer1-plugins-ugly
  gstreamer1-libav
)

audio_application_packages=(
  ardour9
  qtractor
  carla
  hydrogen
)

fedora_audio_plugin_packages=(
  lsp-plugins-vst
  lsp-plugins-clap
  lsp-plugins-lv2
  calf
  guitarix
  lv2-carla
)

daw_runtime_packages=(
  kernel-tools
  libX11
  libXext
  libXcursor
  libXrandr
  libXinerama
  libXv
  dpkg
  libbsd
)

if ! dnf5 -y install \
  "${wine_bridge_packages[@]}" \
  "${copr_audio_workflow_packages[@]}" \
  "${base_system_packages[@]}" \
  "${compatibility_tool_packages[@]}" \
  "${hardware_firmware_packages[@]}" \
  "${hardware_diagnostic_packages[@]}" \
  "${audio_device_packages[@]}" \
  "${audio_server_packages[@]}" \
  "${media_codec_packages[@]}" \
  "${audio_application_packages[@]}" \
  "${fedora_audio_plugin_packages[@]}" \
  "${daw_runtime_packages[@]}"; then

  echo "WARNING: Primary installation failed. Retrying with Patrickl Wine COPRs still enabled..."

  dnf5 -y install \
    "${wine_bridge_packages[@]}" \
    "${copr_audio_workflow_packages[@]}" \
    "${base_system_packages[@]}" \
    "${compatibility_tool_packages[@]}" \
    "${hardware_firmware_packages[@]}" \
    "${hardware_diagnostic_packages[@]}" \
    "${audio_device_packages[@]}" \
    "${audio_server_packages[@]}" \
    "${media_codec_packages[@]}" \
    "${audio_application_packages[@]}" \
    "${fedora_audio_plugin_packages[@]}" \
    "${daw_runtime_packages[@]}"
fi

for optional_package in "${optional_audio_workflow_packages[@]}"; do
  dnf5 -y install "${optional_package}" || {
    echo "WARNING: optional package '${optional_package}' is unavailable; continuing." >&2
  }
done

# Post-install check for Wine (handles the "0KiB" metapackage case)
if ! command -v wine &>/dev/null && ! command -v wine64 &>/dev/null && ! [[ -x /opt/wine-tkg/bin/wine ]]; then
  echo "CRITICAL: Wine binaries missing after installation. Reinstalling Patrickl Wine stack..."
  install_wine_stack
fi

install_wine_stack
validate_wine_stack

kcm_build_packages=(
  cmake
  extra-cmake-modules
  gcc-c++
  kf6-kcmutils-devel
  kf6-kcoreaddons-devel
  kf6-ki18n-devel
  ninja-build
  qt6-qtbase-devel
  qt6-qtdeclarative-devel
)

dnf5 -y install "${kcm_build_packages[@]}"
kcm_qt_plugin_dir="$(qtpaths6 --plugin-dir)"
cmake -S /ctx/kcm-caracal-audio -B /tmp/kcm-caracal-audio-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DKDE_INSTALL_PLUGINDIR="${kcm_qt_plugin_dir}"
cmake --build /tmp/kcm-caracal-audio-build
cmake --install /tmp/kcm-caracal-audio-build
rm -rf /tmp/kcm-caracal-audio-build
dnf5 -y remove --no-autoremove "${kcm_build_packages[@]}" || true

# Virutal Machine Manager and dependencies
dnf -y install @virtualization

dnf -y swap 'ffmpeg-free' 'ffmpeg' --allowerasing

# Bazaar app store
# Bazaar itself is preinstalled as a Flatpak. The KRunner plugin comes from
# ublue-os/packages COPR, which occasionally returns 504s
for attempt in 1 2 3; do
  if dnf5 -y install krunner-bazaar; then
    break
  fi

  if [[ "${attempt}" == "3" ]]; then
    echo "WARNING: krunner-bazaar failed to install after ${attempt} attempts; continuing without the optional KRunner plugin." >&2
    break
  fi

  echo "krunner-bazaar install failed; retrying (${attempt}/3)..." >&2
  sleep $((attempt * 10))
done

# Enable Flathub as a system remote so Bazaar has a populated catalog on first
# boot and `flatpak-preinstall.service` can resolve Caracal's default apps at
# the system scope. Without this the catalog only shows already-installed refs.
# Adapted from Universal Blue's Aurora (ublue-os/aurora):
#   build_files/base/03-fetch.sh and build_files/base/17-cleanup.sh
curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo

systemctl enable flatpak-preinstall.service

install_wine_stack
validate_wine_stack

# System config
sed -Ei "s/secure_path = (.*)/secure_path = \1:\/home\/linuxbrew\/.linuxbrew\/bin/" /etc/sudoers

mkdir -p /etc/sysconfig
echo 'START_OPTS="--governor performance"' >/etc/sysconfig/cpupower

# Realtime/memlock permissions for audio production groups
mkdir -p /etc/security/limits.d
cat >/etc/security/limits.d/audio.conf <<'EOF'
@audio    -  rtprio     95
@audio    -  memlock    unlimited
@realtime -  rtprio     95
@realtime -  memlock    unlimited
EOF

# Graphical apps launched from the user systemd manager inherit limits from
# systemd defaults instead of PAM on some Fedora/KDE session paths. Raise both
# the system and user defaults so REAPER/yabridge can lock memory reliably.
mkdir -p /usr/lib/systemd/system.conf.d /usr/lib/systemd/user.conf.d
cat >/usr/lib/systemd/system.conf.d/90-caracal-audio.conf <<'EOF'
[Manager]
DefaultLimitMEMLOCK=infinity
DefaultLimitRTPRIO=95
EOF
cat >/usr/lib/systemd/user.conf.d/90-caracal-audio.conf <<'EOF'
[Manager]
DefaultLimitMEMLOCK=infinity
DefaultLimitRTPRIO=95
EOF

# Ensure audio group exists (user must run `ujust first-run` or `usermod -aG audio $USER` to join it)
getent group audio || groupadd -r audio

# ── Services ──────────────────────────────────────────────────────────────────
systemctl enable cpupower.service
systemctl enable caracal-cpu-performance.service
systemctl enable caracal-wine-execmod.service
systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable --now libvirtd
for display_manager in gdm.service sddm.service; do
  if systemctl cat "${display_manager}" >/dev/null 2>&1; then
    systemctl disable "${display_manager}" || true
  fi
done
if systemctl cat plasmalogin.service >/dev/null 2>&1; then
  systemctl enable plasmalogin.service
elif systemctl cat sddm.service >/dev/null 2>&1; then
  systemctl enable sddm.service
else
  echo "ERROR: no supported display manager unit found (expected plasmalogin.service or sddm.service)" >&2
  exit 1
fi

chmod +x /usr/libexec/caracal-user-setup
chmod +x /usr/libexec/caracal-cpu-performance
chmod +x /usr/libexec/caracal-wine-execmod
chmod +x /usr/libexec/caracal-setup-launch
chmod +x /usr/libexec/caracal-flatpak-setup
chmod +x /usr/libexec/flatpak-preinstall
systemctl --global enable caracal-setup-launch.service
systemctl --global enable caracal-user-setup.service
systemctl --global enable caracal-user-post-setup.service

# Branding
bash "${SCRIPTS_DIR}/branding.sh"

# Cleanup
rm -rf \
  /var/lib/dnf \
  /var/lib/dpkg \
  /var/lib/alternatives \
  /var/log/dnf* \
  /var/log/hawkey*

rm -rf /usr/etc
