#!/bin/bash
# Caracal OS build script

set -ouex pipefail

SCRIPTS_DIR="/ctx/scripts"

# System files
rsync -rvKlO \
  --exclude='/etc/hostname' \
  --exclude='/usr/bin/caracal-software-installer' \
  --exclude='/usr/lib/caracal-software-installer/***' \
  --exclude='/usr/share/caracal-software-installer/***' \
  --exclude='/usr/share/applications/caracal-software-installer.desktop' \
  /ctx/system_files/shared/ /
echo "caracal" >/etc/hostname

# COPR repositories

dnf5 -y copr enable patrickl/wine-tkg
dnf5 -y copr enable timlau/audio
dnf5 -y copr enable teervo/DISTRHO
dnf5 -y copr enable alternateved/eza
dnf5 -y copr enable ublue-os/packages
dnf5 -y copr enable tumillanino/caracal-software-installer

dnf5 -y install caracal-software-installer

# Realtime support
dnf5 -y install realtime-setup

systemctl enable realtime-setup.service
systemctl enable realtime-entsk.service

# Remove unwanted defaults
dnf5 -y remove \
  zram-generator-defaults \
  nano \
  vim-minimal \
  firefox \
  firefox-langpacks \
  konsole \
  konsole-part \
  plasma-discover \
  plasma-discover-flatpak \
  plasma-discover-kns \
  plasma-discover-libs \
  plasma-discover-notifier \
  plasma-discover-rpm-ostree || true

dnf5 -y swap fedora-logos generic-logos
rpm --erase --nodeps --nodb generic-logos

# COPR audio backages
# Keep disabled packages outside the install array. Inline comments inside a
# backslash-continued command will terminate the command and turn later package
# names into standalone shell commands.
copr_audio_packages=(
  yabridge
  wine.x86_64
  winetricks
  libcurl-gnutls
  Loopino-clap
  dexed-clap
  dexed-vst3
  Crypt2-lv2
  LostAndFoundPiano-lv2
  vst-DISTRHO-drumsynth.x86_64
  vst-DISTRHO-eqinox.x86_64 vst-DISTRHO-vitalium.x86_64
)
dnf5 -y install "${copr_audio_packages[@]}"
# Disabled for image size:
#  vst-DISTRHO-Arctican.x86_64
#  vst-DISTRHO-EasySSP.x86_64
#  vst-DISTRHO-HiReSam.x86_64
#  vst-DISTRHO-JuceOPL.x86_64
#  vst-DISTRHO-KlangFalter.x86_64
#  vst-DISTRHO-LUFS.x86_64
#  vst-DISTRHO-Luftikus.x86_64
#  vst-DISTRHO-Obxd.x86_64
#  vst-DISTRHO-PitchedDelay.x86_64
#  vst-DISTRHO-ReFine.x86_64
#  vst-DISTRHO-StereoSourceSeparation.x86_64
#  vst-DISTRHO-SwankyAmp.x86_64
#  vst-DISTRHO-TAL.x86_64
#  vst-DISTRHO-Temper.x86_64
#  vst-DISTRHO-Vex.x86_64
#  vst-DISTRHO-Wolpertinger.x86_64
#  vst-DISTRHO-dRowAudio.x86_64
#  vst-DISTRHO-drumsynth.x86_64
#  vst-DISTRHO-eqinox.x86_64 vst-DISTRHO-vitalium.x86_64

# Bazaar app store
dnf5 -y install krunner-bazaar

# General tooling
dnf5 -y install \
  zsh \
  openssl \
  openssh \
  7zip \
  rsync \
  neovim \
  alacritty \
  fd-find \
  zoxide \
  fzf \
  python3-tkinter \
  ublue-os-just \
  distrobox

# Virutal Machine Manager and dependencies
dnf -y install @virtualization

# Open source DAWs
dnf5 -y install \
  ardour9 \
  qtractor \
  carla

# Virtual instruments
dnf5 -y install hydrogen

# Audio firmware
dnf -y install \
  alsa-firmware \
  alsa-sof-firmware \
  alsa-tools-firmware \
  intel-audio-firmware \
  atheros-firmware \
  brcmfmac-firmware \
  iwlegacy-firmware \
  iwlwifi-dvm-firmware \
  iwlwifi-mvm-firmware \
  realtek-firmware \
  mt7xxx-firmware \
  nxpwireless-firmware \
  tiwilink-firmware

# JACK Audio
dnf5 -y install \
  jack-audio-connection-kit \
  jack-audio-connection-kit-dbus \
  qjackctl \
  ffado

# Pulse Audio and Pipewire tools
dnf5 -y install \
  pavucontrol \
  pipewire-alsa

# Midi
# dnf5 -y install \
#  qsynth \
#  fluidsynth \
#  fluid-soundfont-gm \
#  timidity++ \
#  qmidiarp \
#  vmpk \
#  harmonyseq

# Audio plugins from official Fedora repos
fedora_audio_plugin_packages=(
  lsp-plugins-vst
  lsp-plugins-clap
  lsp-plugins-lv2
  calf
  guitarix
  lv2-samplv1
  lv2-synthv1
  lv2-drumkv1
  lv2-carla
)
dnf5 -y install "${fedora_audio_plugin_packages[@]}"
# Disabled for image size:
#  zam-plugins
#  lv2-ll-plugins
#  lv2-vocoder-plugins
#  lv2-zynadd-plugins
#  lv2dynparam
#  lv2-abGate
#  lv2-newtonator
#  lv2-x42-plugins
#  lv2-sorcer
#  lv2-fabla

# ── Packages required by native Linux DAWs and the ujust DAW installers ──────
# kernel-tools / libX*: needed by Renoise (and other native apps)
# dpkg + libbsd: needed by ujust install-bitwig (extracts the .deb at runtime)
dnf5 -y install \
  kernel-tools \
  libX11 \
  libXext \
  libXcursor \
  libXrandr \
  libXinerama \
  libXv \
  dpkg \
  libbsd

# Prereqs for WinBoat and nice to haves anyway
dnf5 -y install \
  freerdp \
  podman-compose

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
systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable --now libvirtd

chmod +x /usr/libexec/caracal-user-setup
systemctl --global enable caracal-user-setup.service

# Remove Vapor/VGUI SteamOS theme leftovers from base packages
rm -rf \
  /usr/share/plasma/look-and-feel/com.valve.vapor.desktop \
  /usr/share/plasma/look-and-feel/com.valve.vgui.desktop \
  /usr/share/color-schemes/Vapor.colors \
  /usr/share/plasma/desktoptheme/Vapor

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
