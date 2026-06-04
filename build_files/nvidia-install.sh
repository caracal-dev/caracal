#!/bin/bash
# Install NVIDIA userspace packages from a mounted Bazzite NVIDIA RPM payload.
#
# Adapted from ublue-os/bazzite build_files/install-nvidia (Apache 2.0).

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
    variant_pkgs=(supergfxctl)
    ;;
  silverblue)
    variant_pkgs=(supergfxctl)
    ;;
esac

shopt -s nullglob
local_nvidia_rpms=(
  "${AKMODNV_PATH}"/libnvidia-cfg-*.rpm
  "${AKMODNV_PATH}"/libnvidia-fbc-*.rpm
  "${AKMODNV_PATH}"/libnvidia-gpucomp-*.rpm
  "${AKMODNV_PATH}"/libnvidia-ml-*.rpm
  "${AKMODNV_PATH}"/nvidia-libXNVCtrl-5*.rpm
  "${AKMODNV_PATH}"/nvidia-settings-5*.rpm
  "${AKMODNV_PATH}"/nvidia-driver-*.rpm
  "${AKMODNV_PATH}"/nvidia-kmod-common-*.rpm
  "${AKMODNV_PATH}"/nvidia-modprobe-5*.rpm
  "${AKMODNV_PATH}"/nvidia-persistenced-5*.rpm
  "${AKMODNV_PATH}"/xorg-x11*.rpm
  "${AKMODNV_PATH}"/nvidia-container-toolkit-1*.rpm
  "${AKMODNV_PATH}"/nvidia-container-toolkit-base-1*.rpm
  "${AKMODNV_PATH}"/libnvidia-container1-1*.rpm
  "${AKMODNV_PATH}"/libnvidia-container-tools-1*.rpm
)
shopt -u nullglob

if [[ "${#local_nvidia_rpms[@]}" -eq 0 ]]; then
  echo "No NVIDIA RPMs found in ${AKMODNV_PATH}" >&2
  exit 1
fi

nvidia_pkgs=(
  "${local_nvidia_rpms[@]}"
  libva-nvidia-driver
  "${variant_pkgs[@]}"
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

if [[ -f /etc/yum.repos.d/_copr_ublue-os-staging.repo ]]; then
  sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo
elif [[ -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo ]]; then
  sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ublue-os:staging.repo
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
