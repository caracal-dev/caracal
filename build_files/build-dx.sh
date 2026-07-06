#!/usr/bin/env bash
# Caracal DX build script

set -ouex pipefail

install_optional_package() {
  local package="$1"

  dnf5 -y install "${package}" || {
    echo "WARNING: optional DX package '${package}' is unavailable; continuing." >&2
  }
}

enable_unit_if_present() {
  local unit="$1"

  if systemctl cat "${unit}" >/dev/null 2>&1; then
    systemctl enable "${unit}"
  else
    echo "WARNING: unit '${unit}' is unavailable; not enabling it." >&2
  fi
}

replace_file_if_present() {
  local file="$1"
  local from="$2"
  local to="$3"

  [[ -f "${file}" ]] || return
  sed -i "s|${from}|${to}|g" "${file}"
}

bump_user_setup_version() {
  local key="$1"
  local file="/usr/libexec/caracal-user-setup"
  local version=""

  [[ -f "${file}" ]] || return
  version="$(awk -F= -v key="${key}" '$1 == key {print $2}' "${file}" | tail -n1)"
  [[ "${version}" =~ ^[0-9]+$ ]] || return

  sed -i -E "s|^${key}=[0-9]+$|${key}=$((version + 1))|" "${file}"
}

apply_dx_wallpaper_default() {
  local old_wallpaper="/usr/share/wallpapers/caracal/caracal-lake.png"
  local old_wallpaper_uri="file://${old_wallpaper}"
  local dx_wallpaper="/usr/share/wallpapers/caracal/caracal-silloutte.png"
  local dx_wallpaper_uri="file://${dx_wallpaper}"

  if [[ ! -f "${dx_wallpaper}" ]]; then
    echo "ERROR: DX wallpaper '${dx_wallpaper}' is missing." >&2
    exit 1
  fi

  for config_file in \
    /etc/xdg/kscreenlockerrc \
    /etc/plasmalogin.conf \
    /usr/libexec/caracal-user-setup \
    /usr/share/kde-settings/kde-profile/default/xdg/kscreenlockerrc \
    /usr/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/plasmoidsetupscripts/org.kde.plasma.folder.js \
    /usr/share/sddm/themes/caracal/theme.conf \
    /usr/share/sddm/themes/caracal/theme.conf.user; do
    replace_file_if_present "${config_file}" "${old_wallpaper_uri}" "${dx_wallpaper_uri}"
    replace_file_if_present "${config_file}" "${old_wallpaper}" "${dx_wallpaper}"
  done

  bump_user_setup_version PRE_SESSION_SETUP_VER
  bump_user_setup_version POST_SESSION_SETUP_VER
}

# Apply IP forwarding before installing Docker to avoid disrupting LXC/Incus networking defaults during package post-install setup.
install -d /etc/sysctl.d /etc/modules-load.d
cat >/etc/sysctl.d/90-caracal-dx.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system || true

# Load iptable_nat for docker-in-docker/devcontainer workflows.
cat >/etc/modules-load.d/ip_tables.conf <<'EOF'
iptable_nat
EOF

fedora_dx_packages=(
  android-tools
  bcc
  bpftrace
  cockpit-bridge
  cockpit-machines
  cockpit-networkmanager
  cockpit-ostree
  cockpit-podman
  cockpit-selinux
  cockpit-storaged
  cockpit-system
  cockpit-ws
  edk2-ovmf
  flatpak-builder
  gcc
  golang
  gtk3-devel
  incus
  incus-agent
  iotop
  libvirt
  libvirt-nss
  lxc
  nicstat
  npm
  numactl
  osbuild-selinux
  p7zip
  p7zip-plugins
  pkgconf
  podman-machine
  podman-tui
  qemu
  qemu-char-spice
  qemu-device-display-virtio-gpu
  qemu-device-display-virtio-vga
  qemu-device-usb-redirect
  qemu-img
  qemu-system-x86-core
  qemu-user-binfmt
  qemu-user-static
  sysprof
  trace-cmd
  udica
  virt-manager
  virt-v2v
  virt-viewer
  webkit2gtk4.1-devel
  ydotool
)

dnf5 -y install "${fedora_dx_packages[@]}"

for package in bcvk bpftop; do
  install_optional_package "${package}"
done

if [[ "${IMAGE_NAME:-caracal-dx}" != *nvidia* ]]; then
  for package in rocm-hip rocm-opencl rocm-smi; do
    install_optional_package "${package}"
  done
fi

# Docker packages from the upstream Docker repository.
dnf5 config-manager addrepo --overwrite --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sed -i 's/enabled=.*/enabled=0/g' /etc/yum.repos.d/docker-ce.repo
dnf5 -y install --enablerepo=docker-ce-stable \
  containerd.io \
  docker-buildx-plugin \
  docker-ce \
  docker-ce-cli \
  docker-compose-plugin \
  docker-model-plugin

# VSCodium from the upstream VSCodium RPM repository.
cat >/etc/yum.repos.d/vscodium.repo <<'EOF'
[gitlab.com_paulcarroty_vscodium_repo]
name=gitlab.com_paulcarroty_vscodium_repo
baseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/
enabled=0
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
metadata_expire=1h
EOF
dnf5 -y install --enablerepo=gitlab.com_paulcarroty_vscodium_repo codium

dnf5 -y install ublue-os-libvirt-workarounds || {
  echo "WARNING: ublue-os-libvirt-workarounds is unavailable; continuing without it." >&2
}

if rpm -q docker-ce >/dev/null; then
  enable_unit_if_present docker.socket
fi
enable_unit_if_present podman.socket
enable_unit_if_present cockpit.socket
enable_unit_if_present libvirtd.service
enable_unit_if_present ublue-os-libvirt-workarounds.service

dx_image_name="${IMAGE_NAME:-caracal-dx}"
dx_variant="Developer Experience"
dx_variant_id="caracal-dx"
if [[ "${dx_image_name}" == *nvidia* ]]; then
  dx_variant="Developer Experience NVIDIA"
  dx_variant_id="caracal-dx-nvidia"
fi

echo "${dx_image_name}" >/etc/hostname

for kcm_about in \
  /etc/xdg/kcm-about-distrorc \
  /usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc; do
  if [[ -f "${kcm_about}" ]]; then
    sed -i "s/^Variant=.*/Variant=${dx_variant}/" "${kcm_about}"
  fi
done

if grep -q '^VARIANT=' /usr/lib/os-release; then
  sed -i "s|^VARIANT=.*|VARIANT=\"Caracal OS ${dx_variant}\"|" /usr/lib/os-release
else
  printf 'VARIANT="Caracal OS %s"\n' "${dx_variant}" >>/usr/lib/os-release
fi
if grep -q '^VARIANT_ID=' /usr/lib/os-release; then
  sed -i "s|^VARIANT_ID=.*|VARIANT_ID=${dx_variant_id}|" /usr/lib/os-release
else
  printf 'VARIANT_ID=%s\n' "${dx_variant_id}" >>/usr/lib/os-release
fi

apply_dx_wallpaper_default

# Keep third-party repos present for installed packages but disabled by default.
for repo_file in /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/vscodium.repo; do
  [[ -f "${repo_file}" ]] && sed -i 's/enabled=.*/enabled=0/g' "${repo_file}"
done
