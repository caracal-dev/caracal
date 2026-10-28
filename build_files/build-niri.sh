#!/bin/bash
# Caracal Niri image build script.
#
# Minimal Wayland desktop on the generic fedora-bootc base (no KDE/GNOME
# payload): niri compositor + Dank Material Shell (DMS) as the session shell,
# greetd + dms-greeter as the login screen. Caracal branding and the Kanagawa
# Dragon theme are preset out of the box. The audio-workstation stack built by
# build.sh (Wine, DAWs, plugins) is intentionally NOT part of this image.
#
# Pattern follows Zena's bootc build (references/Zena), adapted to Caracal:
# no CachyOS kernel (OGC kernel is swapped in install-kernel before this
# script), no Nix, no systemd-homed, no MangoWC -- just Niri with DMS.

set -ouex pipefail

DESKTOP="niri"

# Tooling the generic fedora-bootc base lacks: rsync (system_files overlay
# below) and dnf5-plugins (COPR enablement).
dnf5 -y install rsync dnf5-plugins

# System files (configs, skel, units, theme). Standalone overlay -- the shared
# audio-workstation system_files are not part of this image.
rsync -rvKlO /ctx/system_files/${DESKTOP}/ /

echo "caracal" >/etc/hostname

SCRIPTS_DIR="/ctx/scripts"

# ── Repositories ─────────────────────────────────────────────────────────────
# retries: COPR downloads hit transient TLS resets on some networks; librepo's
# default of 2 is not enough.
printf '%s\n' 'max_parallel_downloads=10' 'retries=20' >>/etc/dnf/dnf.conf

coprs=(
  yalter/niri
  avengemedia/dms
  avengemedia/danklinux
)

for copr in "${coprs[@]}"; do
  echo "Enabling copr: $copr"
  dnf5 -y copr enable "${copr}"
done

# niri from yalter's COPR wins over anything Fedora ships; the DMS
# quickshell stack (quickshell, matugen, dsearch, greeter deps) comes next.
echo "priority=1" | tee -a /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri.repo
echo "priority=2" | tee -a /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:avengemedia:danklinux.repo

# The COPR download endpoint intermittently resets TLS on some networks; dnf's
# retry loop can exhaust on the 1 kB repo key fetch while big package downloads
# succeed. Pin each COPR key locally (same key, fetched with generous curl
# retries) and point the repo files at it -- signature verification stays on.
mkdir -p /etc/pki/copr
for repo_file in /etc/yum.repos.d/_copr*.repo; do
  key_url=$(grep -m1 '^gpgkey=' "$repo_file" | sed 's/^gpgkey=//')
  [ -z "${key_url}" ] && continue
  key_path="/etc/pki/copr/$(basename "${repo_file}" .repo).gpg"
  curl --retry 20 --retry-all-errors --retry-delay 2 -fsSL "${key_url}" -o "${key_path}"
  sed -i "s|^gpgkey=.*|gpgkey=file://${key_path}|" "${repo_file}"
done

# ── Base desktop packages ────────────────────────────────────────────────────
packages=(
  # Compositor + shell (niri pulls xwayland-satellite + xorg-x11-server-Xwayland)
  niri
  dms
  dms-greeter
  greetd

  # Default applications
  ghostty
  nautilus
  glycin-thumbnailer

  # Themes and fonts (DMS needs Inter + Fira Code + Material Symbols;
  # Material Symbols comes from the danklinux COPR as a dms dependency)
  adw-gtk3-theme
  papirus-icon-theme
  fira-code-fonts
  rsms-inter-fonts
  default-fonts
  default-fonts-core-emoji
  google-noto-color-emoji-fonts
  glibc-all-langpacks

  # Portals and session plumbing
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-gnome
  xdg-user-dirs
  xdg-terminal-exec
  xdg-utils
  wl-clipboard
  gvfs
  gnome-keyring
  gnome-keyring-pam
  pinentry-gnome3

  # Hardware support
  NetworkManager
  NetworkManager-wifi
  NetworkManager-bluetooth
  NetworkManager-config-connectivity-fedora
  bluez
  pipewire
  pipewire-pulse
  pipewire-alsa
  wireplumber
  alsa-sof-firmware
  alsa-firmware
  linux-firmware
  cups
  cups-pk-helper
  fwupd
  power-profiles-daemon
  thermald

  # System
  chrony
  firewalld
  plymouth
  plymouth-system-theme
  bootupd

  # Virtualization guests (BIB qcow2/VM testing)
  qemu-guest-agent
  spice-vdagent

  # Applications
  flatpak
)

dnf5 -y install "${packages[@]}"

# dms pulls alacritty in as a weak dependency; this image ships Ghostty only
# (xdg-terminal-exec resolves com.mitchellh.ghostty.desktop).
dnf5 -y remove alacritty

# Fedora 44 keeps supplementary groups in the usr-merged /usr/lib/group: NSS
# resolves them (so getent/groupadd refuse them as existing) but useradd
# reads /etc/group directly. Materialize them so user creation with
# supplementary groups works on first boot (same fix as build-gnome-de.sh).
for entry in 'audio:x:63:' 'video:x:39:' 'input:x:104:' 'render:x:105:'; do
  grp="${entry%%:*}"
  grep -q "^${grp}:" /etc/group || echo "$entry" >>/etc/group
done

# ── DAW defaults ─────────────────────────────────────────────────────────────
# Realtime audio permissions for DAWs (REAPER, Ardour, Bitwig, Wine/Yabridge
# plugin hosts), matching the Caracal audio images. Users join the `audio`
# group to get rtprio/memlock; limits apply system-wide and to user services.
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

# The overlay rsync drops exec bits: restore them for the helper scripts.
chmod +x \
  /usr/libexec/dms-greeter-sync.sh \
  /usr/libexec/dms-greeter-sync-trigger.sh \
  /usr/libexec/caracal-niri-user-setup

# Compile the dconf system database (icon theme, dark color scheme).
dconf update

# ── Session entry ────────────────────────────────────────────────────────────
# dms-greeter launches the user session straight from greetd (no session
# manager); silence niri-session's startup chatter so the greeter console
# stays clean.
sed -i 's|^Exec=.*|Exec=bash -c "niri-session > /dev/null 2>\&1"|' \
  /usr/share/wayland-sessions/niri.desktop

# ── SELinux: greeter state dirs must be writable by the xdm_t domain ────────
# greetd runs its sessions confined as xdm_t. The dms-greeter package owns
# /var/cache/dms-greeter and /var/lib/greeter, but Fedora's policy labels
# /var/cache/* as var_t and /var/lib/* as var_lib_t, and xdm_t may create in
# neither. The greeter then dies instantly on its first cache write (EACCES),
# greetd exhausts its restart limit, and the boot stalls on the plymouth
# splash. Map both trees onto xdm_var_lib_t -- the type xdm_t is allowed to
# manage (it is what GDM's /var/lib/gdm uses) -- and relabel at boot, before
# greetd starts. file_contexts.local makes matchpathcon return the right type
# for freshly created paths (first boot); the tmpfiles Z rule relabels paths
# that already exist on disk (upgrades of existing installs).
mkdir -p /etc/selinux/targeted/contexts/files
local_fc=/etc/selinux/targeted/contexts/files/file_contexts.local
touch "${local_fc}"
grep -q '/var/lib/greeter' "${local_fc}" || cat >>"${local_fc}" <<'EOF'
/var/lib/greeter(/.*)?        system_u:object_r:xdm_var_lib_t:s0
/var/cache/dms-greeter(/.*)?  system_u:object_r:xdm_var_lib_t:s0
EOF
cat >/etc/tmpfiles.d/caracal-niri-greeter.conf <<'EOF'
# Relabel the DMS greeter state for xdm_t (see build-niri.sh SELinux note).
# Modes mirror /usr/lib/tmpfiles.d/dms-greeter.conf; this file sorts before
# it, so creation on first boot already lands on xdm_var_lib_t.
Z /var/lib/greeter 0755 greeter greeter -
Z /var/cache/dms-greeter 0750 greeter greeter -
EOF

# ── Flathub ──────────────────────────────────────────────────────────────────
# System-wide Flathub so the Flatpak portal app catalogs are populated.
curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo \
  https://dl.flathub.org/repo/flathub.flatpakrepo
echo "Default=true" | tee -a /etc/flatpak/remotes.d/flathub.flatpakrepo >/dev/null
flatpak remote-add --if-not-exists --system flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
flatpak remote-modify --system --enable flathub

# ── Services ─────────────────────────────────────────────────────────────────
system_services=(
  greetd.service
  flatpak-theme.service
  thermald.service
  chronyd.service
  firewalld.service
)

user_services=(
  dms.service
  dms-watch.path
  dsearch.service
  dms-greeter-sync-trigger.service
  caracal-niri-setup.service
  gnome-keyring-daemon.socket
  gnome-keyring-daemon.service
)

systemctl enable "${system_services[@]}"

# The generic fedora-bootc base defaults to multi-user.target; the desktop
# session stack (greetd, plymouth splash, graphical-session.target for DMS)
# requires graphical.target as the boot default.
systemctl set-default graphical.target

# Mask services that just slow boot or fight the image (none of the KDE/GNOME
# update plumbing exists on this base, but NetworkManager-wait-online is
# present via NetworkManager and only delays boot).
systemctl mask NetworkManager-wait-online.service

preset_file="/usr/lib/systemd/system-preset/01-caracal-niri.preset"
touch "$preset_file"
for service in "${system_services[@]}"; do
  echo "enable $service" >>"$preset_file"
done

mkdir -p /etc/systemd/user-preset/
preset_file="/etc/systemd/user-preset/01-caracal-niri.preset"
touch "$preset_file"
for service in "${user_services[@]}"; do
  echo "enable $service" >>"$preset_file"
done
systemctl --global preset-all

# ── Branding ─────────────────────────────────────────────────────────────────
# Caracal logo, wallpapers, Plymouth watermark, EFI icon, os-release identity.
bash "${SCRIPTS_DIR:-/ctx/scripts}/branding.sh"

# ── Container signature policy ───────────────────────────────────────────────
# Same policy as the other Caracal images (see build.sh tail).
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/caracal.pub
install -Dm0644 /ctx/signing/containers/policy.json /etc/containers/policy.json
install -Dm0644 /ctx/signing/containers/registries.d/caracal.yaml /etc/containers/registries.d/caracal.yaml

# ── Cleanup ──────────────────────────────────────────────────────────────────
rm -rf \
  /var/lib/dnf \
  /var/lib/dpkg \
  /var/lib/alternatives \
  /var/log/dnf* \
  /var/log/hawkey*

rm -rf /usr/etc