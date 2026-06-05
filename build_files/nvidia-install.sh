#!/bin/bash
# Install NVIDIA userspace packages and prebuilt kmods from a mounted akmods
# NVIDIA RPM payload.
#
# Adapted from ublue-os/main build_files/nvidia-install.sh (Apache 2.0).

set -ouex pipefail

FRELEASE="$(rpm -E %fedora)"
: "${AKMODNV_PATH:=/rpms/nvidia}"
: "${IMAGE_NAME:=kinoite}"
: "${MULTILIB:=1}"

# Aid CI debugging when upstream payload layouts change.
if [[ ! -d "${AKMODNV_PATH}" ]]; then
  echo "NVIDIA RPM payload directory does not exist: ${AKMODNV_PATH}" >&2
  exit 1
fi
find "${AKMODNV_PATH}"/

if ! command -v dnf5 >/dev/null; then
  echo "Requires dnf5. Exiting"
  exit 1
fi

dnf5 install -y "${AKMODNV_PATH}"/ublue-os/ublue-os-nvidia-addons-*.rpm

if dnf5 repolist --all | grep -q rpmfusion; then
  dnf5 config-manager setopt "rpmfusion*".enabled=0
fi
dnf5 config-manager setopt fedora-cisco-openh264.enabled=0 || true

if [[ "${MULTILIB}" != "0" ]]; then
  multilib_pkgs=(
    mesa-dri-drivers.i686
    mesa-filesystem.i686
    mesa-libEGL.i686
    mesa-libGL.i686
    mesa-libgbm.i686
    mesa-va-drivers.i686
    mesa-vulkan-drivers.i686
  )
  dnf5 install -y "${multilib_pkgs[@]}"
fi

dnf5 config-manager setopt fedora-nvidia.enabled=1 nvidia-container-toolkit.enabled=1

negativo17_mult_prev_enabled=N
if dnf5 repolist --enabled | grep -q "fedora-multimedia"; then
  negativo17_mult_prev_enabled=Y
  dnf5 config-manager setopt fedora-multimedia.enabled=0
fi

# Enable ublue-os/staging for supergfxctl packages.
if [[ -f /etc/yum.repos.d/_copr_ublue-os-staging.repo ]]; then
  sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo
elif [[ -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo ]]; then
  sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo
else
  curl -Lo /etc/yum.repos.d/_copr_ublue-os-staging.repo \
    "https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-${FRELEASE}/ublue-os-staging-fedora-${FRELEASE}.repo"
fi

variant_pkgs=()
case "${IMAGE_NAME}" in
  kinoite)
    variant_pkgs=(supergfxctl-plasmoid supergfxctl)
    ;;
  silverblue)
    variant_pkgs=(gnome-shell-extension-supergfxctl-gex supergfxctl)
    ;;
esac

source "${AKMODNV_PATH}"/kmods/nvidia-vars

nvidia_pkgs=(
  libnvidia-fbc
  libva-nvidia-driver
  nvidia-driver
  nvidia-driver-cuda
  nvidia-settings
  nvidia-container-toolkit
  "${variant_pkgs[@]}"
  "${AKMODNV_PATH}"/kmods/kmod-nvidia-"${KERNEL_VERSION}"-"${NVIDIA_AKMOD_VERSION}"."${DIST_ARCH}".rpm
)

if [[ "${MULTILIB}" != "0" ]]; then
  nvidia_pkgs+=(
    libnvidia-ml.i686
    nvidia-driver-cuda-libs.i686
    nvidia-driver-libs.i686
  )
fi

dnf5 install -y "${nvidia_pkgs[@]}"

if ! rpm -q --whatprovides nvidia-kmod >/dev/null; then
  echo "Error: no installed package provides nvidia-kmod" >&2
  exit 1
fi

kmod_version="$(rpm -q --queryformat '%{VERSION}' kmod-nvidia)"
driver_version="$(rpm -q --queryformat '%{VERSION}' nvidia-driver)"
if [[ "${kmod_version}" != "${driver_version}" ]]; then
  echo "Error: kmod-nvidia version (${kmod_version}) does not match nvidia-driver version (${driver_version})" >&2
  exit 1
fi

dnf5 config-manager setopt fedora-nvidia.enabled=0 fedora-nvidia-lts.enabled=0 nvidia-container-toolkit.enabled=0

if [[ -f /etc/yum.repos.d/_copr_ublue-os-staging.repo ]]; then
  sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo
elif [[ -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo ]]; then
  sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo
fi

if [[ "${negativo17_mult_prev_enabled}" == "Y" ]]; then
  dnf5 config-manager setopt fedora-multimedia.enabled=1
fi

systemctl enable ublue-nvctk-cdi.service
if [[ -f /usr/share/selinux/packages/nvidia-container.pp ]]; then
  semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp
fi

if [[ -f /etc/modprobe.d/nvidia-modeset.conf ]]; then
  cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
fi

if [[ -f /usr/lib/dracut/dracut.conf.d/99-nvidia.conf ]]; then
  sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
  sed -i 's@ nvidia @ i915 amdgpu nvidia @g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
fi
