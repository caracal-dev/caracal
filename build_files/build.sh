#!/bin/bash
# Caracal OS build script

set -ouex pipefail

SCRIPTS_DIR="/ctx/scripts"
YABRIDGE_VERSION="5.1.1"

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
  rpm -q wine-core wine-common winetricks || {
    echo "CRITICAL ERROR: required Wine RPMs are missing!" >&2
    dnf5 list installed "wine*" "yabridge*" "winetricks*" || true
    exit 1
  }

  local wine_found=0
  local bin
  for bin in /usr/bin/wine /usr/bin/wine64 /usr/sbin/wine /usr/sbin/wine64 /opt/wine-tkg/bin/wine /opt/wine-tkg/bin/wine64; do
    if [[ -x "$bin" ]]; then
      wine_found=1
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

  echo "Checking for real 32-bit Wine prefix support..."
  local win32_prefix
  win32_prefix="$(mktemp -d /tmp/caracal-wine32-check.XXXXXX)"
  if ! WINEARCH=win32 WINEPREFIX="${win32_prefix}" WINEDEBUG=-all "${wineboot_bin}" -u; then
    rm -rf "${win32_prefix}"
    echo "CRITICAL ERROR: Wine cannot create a win32 prefix." >&2
    echo "Install the matching Fedora x86_64 and i686 Wine packages together." >&2
    dnf5 list installed "wine*" || true
    exit 1
  fi
  rm -rf "${win32_prefix}"

  echo "Wine and Yabridge validation successful."
}

install_yabridge_release() {
  local tmpdir
  tmpdir="$(mktemp -d /tmp/caracal-yabridge.XXXXXX)"
  curl -fL \
    "https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/yabridge-${YABRIDGE_VERSION}.tar.gz" \
    -o "${tmpdir}/yabridge.tar.gz"
  tar -C "${tmpdir}" -xzf "${tmpdir}/yabridge.tar.gz"
  install -d /usr/libexec/yabridge
  cp -a "${tmpdir}/yabridge/." /usr/libexec/yabridge/
  local doc
  for doc in README.md CHANGELOG.md; do
    if [[ -f "${tmpdir}/yabridge/${doc}" ]]; then
      install -Dm0644 "${tmpdir}/yabridge/${doc}" "/usr/share/doc/yabridge/${doc}"
    fi
  done
  ln -sf /usr/libexec/yabridge/yabridgectl /usr/bin/yabridgectl
  rm -rf "${tmpdir}"
}

install_wine_stack() {
  dnf5 -y install "${wine_bridge_packages[@]}" "${wine_multilib_packages[@]}"
  install_yabridge_release
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
    wine.i686 \
    wine-core.i686 \
    wine-alsa.i686 \
    wine-cms.i686 \
    wine-pulseaudio.i686 \
    winetricks \
    || true
}

# Use Fedora Wine as one matched multilib set. Patrickl's Wine COPRs currently
# provide newer x86_64/noarch Wine packages but no matching i686 packages, so
# enabling them prevents win32 installer support.
dnf5 -y copr disable patrickl/wine-11.8-vstgui-juce8 || true
dnf5 -y copr disable patrickl/wine-tkg-dev || true

# COPR repositories
copr_repos=(
  timlau/audio
  teervo/DISTRHO
  ublue-os/packages
  ublue-os/staging
  tumillanino/caracal-packages
)
for copr_repo in "${copr_repos[@]}"; do
  dnf5 -y copr enable "${copr_repo}"
done

dnf -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
# Fedora ostree images expose /opt through /var/opt. Materialize the backing
# directory before installing RPMs that unpack files directly under /opt.
install -d /var/opt
dnf -y install "https://github.com/TheAssassin/AppImageLauncher/releases/download/v3.0.0-beta-3/appimagelauncher_3.0.0-beta-2-gha287.96cb937_x86_64.rpm"
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
  wine.x86_64
  wine-core.x86_64
  wine-alsa.x86_64
  wine-cms.x86_64
  wine-common.noarch
  wine-desktop.noarch
  wine-pulseaudio.x86_64
  wine-winefonts.noarch
  winetricks
  wine-mono
  wine-dxvk
  #  pipewire-wineasio
)

wine_multilib_packages=(
  wine.i686
  wine-core.i686
  wine-alsa.i686
  wine-cms.i686
  wine-pulseaudio.i686
)

copr_audio_workflow_packages=(
  appimagelauncher
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
  "${wine_multilib_packages[@]}" \
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

  echo "WARNING: Primary installation failed. Attempting fallback by disabling Patrickl COPRs..."
  dnf5 -y copr disable patrickl/wine-11.8-vstgui-juce8 || true
  dnf5 -y copr disable patrickl/wine-tkg-dev || true

  dnf5 -y install \
    "${wine_bridge_packages[@]}" \
    "${wine_multilib_packages[@]}" \
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
  echo "CRITICAL: Wine binaries missing after installation. Forcing fallback to Fedora Wine..."
  dnf5 -y copr disable patrickl/wine-11.8-vstgui-juce8 || true
  dnf5 -y copr disable patrickl/wine-tkg-dev || true
  # Use swap to replace any broken/dummy packages with the official ones
  dnf5 -y --allowerasing install wine wine-core wine-common wine.i686 wine-core.i686
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
chmod +x /usr/libexec/caracal-setup-launch
chmod +x /usr/libexec/caracal-flatpak-setup
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
