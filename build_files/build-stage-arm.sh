#!/bin/bash
# Caracal Stage ARM build script — no Wine/yabridge, stock kernel

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
echo "caracal-stage-arm" >/etc/hostname

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

# No Wine COPR enablement — Wine/TKG is x86_64-only and not available on aarch64

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
bash /ctx/scripts/install-appimagelauncher.sh
dnf -y install "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"

dnf5 -y install caracal-audio-controller realtime-setup caracal-software-installer

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

  echo "WARNING: Primary installation failed. Retrying..."
  dnf5 -y install \
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

for distrho_plugin in "${distrho_plugins[@]}"; do
  dnf5 -y install "${distrho_plugin}" || {
    echo "WARNING: DISTRHO plugin '${distrho_plugin}' is unavailable on this architecture; continuing." >&2
  }
done

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
getent group video >/dev/null && usermod -aG video greeter || true
install -d -o greeter -g greeter -m 0755 /var/lib/greetd

# Fresh ISO installs via Universal Blue's Anaconda WebUI create no login account.
# caracal-stage-firstboot creates the primary user on first boot (before greetd)
# when none exists; caracal-stage-autologin then autologins it.
systemctl enable caracal-stage-firstboot.service
systemctl enable caracal-stage-autologin.service
# Run `ujust first-run` automatically on each user's first Stage login.
systemctl --global enable caracal-stage-first-run.service

systemctl enable greetd.service
systemctl set-default graphical.target

chmod +x /usr/libexec/caracal-user-setup
chmod +x /usr/libexec/caracal-cpu-performance
chmod +x /usr/libexec/caracal-stage-autologin
chmod +x /usr/libexec/caracal-stage-firstboot
chmod +x /usr/libexec/caracal-stage-first-run

chmod +x /usr/bin/caracal-stage
chmod +x /usr/bin/caracal-stage-session
chmod +x /usr/bin/caracal-stage-carla

rm -rf \
  /var/lib/dnf \
  /var/lib/dpkg \
  /var/lib/alternatives \
  /var/log/dnf* \
  /var/log/hawkey*

rm -rf /usr/etc

