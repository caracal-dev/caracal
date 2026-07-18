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
  chromium
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

# Keep third-party repos present for installed packages but disabled by default.
for repo_file in /etc/yum.repos.d/docker-ce.repo /etc/yum.repos.d/vscodium.repo; do
  [[ -f "${repo_file}" ]] && sed -i 's/enabled=.*/enabled=0/g' "${repo_file}"
done
