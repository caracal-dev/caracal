#!/bin/bash
# Caracal Stage build script

set -ouex pipefail

rsync -rvKlO \
  --exclude='/etc/hostname' \
  --exclude='/etc/sddm.conf.d/***' \
  --exclude='/etc/xdg/autostart/***' \
  --exclude='/etc/xdg/kactivitymanagerd-statsrc' \
  --exclude='/etc/xdg/kdeglobals' \
  --exclude='/etc/xdg/kscreenlockerrc' \
  --exclude='/etc/xdg/ksplashrc' \
  --exclude='/etc/xdg/kwinrc' \
  --exclude='/etc/xdg/plasmarc' \
  --exclude='/usr/lib/sddm/***' \
  --exclude='/usr/lib/systemd/user/bazaar.service' \
  --exclude='/usr/lib/systemd/user/caracal-setup-launch.service' \
  --exclude='/usr/lib/systemd/user/caracal-user-post-setup.service' \
  --exclude='/usr/lib/systemd/user/caracal-user-setup.service' \
  --exclude='/usr/share/applications/caracal-software-installer.desktop' \
  --exclude='/usr/share/applications/kcm_caracal_audio.desktop' \
  --exclude='/usr/share/flatpak/***' \
  --exclude='/usr/share/kde-settings/***' \
  --exclude='/usr/share/plasma/***' \
  --exclude='/usr/share/ublue-os/bazaar/***' \
  --exclude='/usr/share/ublue-os/homebrew/***' \
  /ctx/system_files/shared/ /
rsync -rvKlO /ctx/system_files/stage/ /
echo "caracal-stage" >/etc/hostname

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
    ls -l /usr/bin/wine* /usr/sbin/wineboot /opt/wine-tkg/bin/wineboot 2>/dev/null || true
    exit 1
  fi

  if ! command -v yabridgectl &>/dev/null; then
    echo "CRITICAL ERROR: yabridgectl not found!" >&2
    exit 1
  fi

  source /usr/share/caracal/version-pins
  local wine_version=""
  wine_version="$("${wine_bin}" --version 2>/dev/null || true)"
  echo "Wine version: ${wine_version:-unknown}"
  if [[ "${wine_version}" != wine-${WINE_VERSION}* ]]; then
    echo "CRITICAL ERROR: expected Patrickl's wine-staging-dev Wine ${WINE_VERSION} stack, got '${wine_version:-unknown}'." >&2
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
  local pe32_output=""
  if [[ -n "${wine_i386_cmd}" ]]; then
    pe32_output="$(WINEPREFIX="${wow64_prefix}" WINEDEBUG=-all "${wine_bin}" "${wine_i386_cmd}" /c ver 2>/dev/null || true)"
  fi
  if [[ -z "${wine_i386_cmd}" ]] || ! grep -qi 'Microsoft Windows' <<<"${pe32_output}"; then
    WINEPREFIX="${wow64_prefix}" wineserver -w 2>/dev/null || true
    rm -rf "${wow64_prefix}"
    echo "WARNING: Wine could not run a PE32 program through WoW64 at build time." >&2
    echo "On the deployed composefs root this is handled by caracal-wine-execmod.service." >&2
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
    wine-mono \
    wine-dxvk \
    winetricks \
    yabridge \
    ntsync-autoload \
    pipewire-wineasio ||
    true
}

if dnf5 -y copr enable patrickl/wine-staging-dev; then
  set_copr_priority patrickl wine-staging-dev 80
else
  echo "WARNING: failed to enable patrickl/wine-staging-dev; falling back to patrickl/wine-tkg-dev." >&2
fi

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

# SC2016: single-quote intentional — $releasever is a dnf URL template, expanded by dnf, not by bash
# shellcheck disable=SC2016
dnf -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
bash /ctx/scripts/install-appimagelauncher.sh
dnf -y install "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

dnf5 -y install caracal-audio-controller realtime-setup caracal-software-installer

# Caracal audio daemon (control plane) + Carla OSC adapter. The adapter is
# a small Python sidecar that owns Carla's host API; the daemon is a Go
# HTTP/JSON service that the Wails app talks to. Both are installed as
# per-user services so they live in the kiosk user's session bus.
if ! dnf5 -y install caracal-audio-daemon caracal-carla-adapter; then
  echo "WARNING: caracal-audio-daemon / caracal-carla-adapter RPMs unavailable; falling back to source install." >&2
  if [[ -d /ctx/caracal-go/caracal-audio-daemon ]]; then
    install -d /usr/share/caracal-stage
    install -m 0644 /ctx/caracal-go/caracal-audio-daemon/packaging/carla-adapter.py /usr/share/caracal-stage/carla-adapter.py
    install -m 0644 /ctx/caracal-go/caracal-audio-daemon/packaging/carla-discover.py /usr/share/caracal-stage/carla-discover.py
  fi
fi

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
  konsole
  dolphin
  ark
  kate
  kwrite
  okular
  elisa-player
  haruna
  khelpcenter
  plasma-welcome
  plasma-systemmonitor
  spectacle
)
dnf5 -y remove "${default_packages_to_remove[@]}" || true

dnf5 -y swap fedora-logos generic-logos
rpm --erase --nodeps --nodb generic-logos

wine_bridge_packages=(
  yabridge
  wine
  wine-mono
  wine-dxvk
  winetricks
  ntsync-autoload
  pipewire-wineasio
)

stage_shell_packages=(
  zsh
  openssl
  openssh
  foot
  7zip
  neovim
  ublue-os-just
  zenity
)

stage_wayland_packages=(
  greetd
  wayfire
  wf-shell
  wlr-randr
  xdg-desktop-portal
  xdg-desktop-portal-wlr
  xdg-desktop-portal-gtk
  qt6-qtwayland
  wl-clipboard
  brightnessctl
  playerctl
)

stage_optional_keyboard_packages=(
  wayfire-plugins-extra
  wvkbd
  squeekboard
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
  pavucontrol
  pipewire-alsa
  pipewire-utils
  helvum
  rtkit
  tuned-profiles-realtime
  wireplumber
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

stage_audio_application_packages=(
  carla
)

audio_plugin_packages=(
  lsp-plugins-vst
  lsp-plugins-clap
  lsp-plugins-lv2
  lv2-carla
  vst-DISTRHO-drumsynth.x86_64
  vst-DISTRHO-eqinox.x86_64
  vst-DISTRHO-vitalium.x86_64
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
  libcurl-gnutls
)

if ! dnf5 -y install \
  "${wine_bridge_packages[@]}" \
  "${stage_shell_packages[@]}" \
  "${stage_wayland_packages[@]}" \
  "${hardware_firmware_packages[@]}" \
  "${hardware_diagnostic_packages[@]}" \
  "${audio_device_packages[@]}" \
  "${audio_server_packages[@]}" \
  "${media_codec_packages[@]}" \
  "${stage_audio_application_packages[@]}" \
  "${audio_plugin_packages[@]}" \
  "${daw_runtime_packages[@]}"; then

  echo "WARNING: Primary installation failed. Retrying with Patrickl Wine COPRs still enabled..."

  dnf5 -y install \
    "${wine_bridge_packages[@]}" \
    "${stage_shell_packages[@]}" \
    "${stage_wayland_packages[@]}" \
    "${hardware_firmware_packages[@]}" \
    "${hardware_diagnostic_packages[@]}" \
    "${audio_device_packages[@]}" \
    "${audio_server_packages[@]}" \
    "${media_codec_packages[@]}" \
    "${stage_audio_application_packages[@]}" \
    "${audio_plugin_packages[@]}" \
    "${daw_runtime_packages[@]}"
fi

for optional_package in "${stage_optional_keyboard_packages[@]}"; do
  dnf5 -y install "${optional_package}" || {
    echo "WARNING: optional package '${optional_package}' is unavailable; continuing." >&2
  }
done

if ! command -v wine &>/dev/null && ! command -v wine64 &>/dev/null && ! [[ -x /opt/wine-tkg/bin/wine ]]; then
  echo "CRITICAL: Wine binaries missing after installation. Reinstalling Patrickl Wine stack..."
  install_wine_stack
fi

install_wine_stack
validate_wine_stack

dnf -y swap 'ffmpeg-free' 'ffmpeg' --allowerasing

sed -Ei "s/secure_path = (.*)/secure_path = \1:\/home\/linuxbrew\/.linuxbrew\/bin/" /etc/sudoers

mkdir -p /etc/sysconfig
echo 'START_OPTS="--governor performance"' >/etc/sysconfig/cpupower

mkdir -p /etc/security/limits.d
cat >/etc/security/limits.d/audio.conf <<'EOF'
@audio    -  rtprio     95
@audio    -  memlock    unlimited
@realtime -  rtprio     95
@realtime -  memlock    unlimited
EOF

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

getent group audio || groupadd -r audio

systemctl enable cpupower.service
systemctl enable caracal-cpu-performance.service
systemctl enable caracal-wine-execmod.service

# Boot straight into the Wayfire/Carla session via greetd autologin. Disable the
# heavier desktop display managers first so they do not fight greetd over a VT.
for display_manager in gdm.service sddm.service plasmalogin.service; do
  if systemctl cat "${display_manager}" >/dev/null 2>&1; then
    systemctl disable "${display_manager}" || true
  fi
done
# greetd validates default_session.user at startup and Fedora's greetd RPM does not create the greeter account
if ! getent passwd greeter >/dev/null; then
  useradd --system --no-create-home --home-dir /var/lib/greetd \
    --shell /usr/sbin/nologin --comment "greetd greeter" --user-group greeter
fi
if getent group video >/dev/null; then
  usermod -aG video greeter || true
fi
install -d -o greeter -g greeter -m 0755 /var/lib/greetd

# Fresh ISO installs via Universal Blue's Anaconda WebUI create no login account.
# caracal-stage-firstboot creates the primary user on first boot (before greetd)
# when none exists; caracal-stage-autologin then autologins it.
systemctl enable caracal-stage-firstboot.service
systemctl enable caracal-stage-autologin.service
# Run `ujust first-run` automatically on each user's first Stage login.
systemctl --global enable caracal-stage-first-run.service
# Bring up the audio control plane + Carla OSC adapter in every kiosk
# user session. They are part of the default user target so the kiosk
# session can rely on them at login.
if systemctl cat caracal-audio-daemon.service >/dev/null 2>&1; then
  systemctl --global enable caracal-audio-daemon.service
fi
if systemctl cat carla-adapter.service >/dev/null 2>&1; then
  systemctl --global enable carla-adapter.service
fi

systemctl enable greetd.service
systemctl set-default graphical.target

chmod +x /usr/libexec/caracal-user-setup
chmod +x /usr/libexec/caracal-cpu-performance
chmod +x /usr/libexec/caracal-wine-execmod
chmod +x /usr/libexec/caracal-stage-autologin
chmod +x /usr/libexec/caracal-stage-firstboot
chmod +x /usr/libexec/caracal-stage-first-run

chmod +x /usr/bin/caracal-stage
chmod +x /usr/bin/caracal-stage-session
chmod +x /usr/bin/caracal-stage-carla
chmod +x /usr/share/caracal-stage/carla-adapter.py 2>/dev/null || true
chmod +x /usr/share/caracal-stage/carla-discover.py 2>/dev/null || true

rm -rf \
  /var/lib/dnf \
  /var/lib/dpkg \
  /var/lib/alternatives \
  /var/log/dnf* \
  /var/log/hawkey*

rm -rf /usr/etc
