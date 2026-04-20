#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <plugin-id> <display-name> <url> <primary-bundle-name> [formats] [data-dir-name] [data-target-name]" >&2
  echo "Formats: comma-separated subset of clap,vst,vst3,lv2 (default: clap,vst,vst3,lv2)" >&2
  exit 1
fi

plugin_id="$1"
display_name="$2"
url="$3"
primary_bundle_name="$4"
formats="${5:-clap,vst,vst3,lv2}"
data_dir_name="${6:-}"
data_target_name="${7:-${data_dir_name}}"

workdir="$(mktemp -d)"
archive_path="${workdir}/${plugin_id}.zip"
extract_dir="${workdir}/extract"
target_vst_dir="${HOME}/.vst"
target_vst3_dir="${HOME}/.vst3"
target_lv2_dir="${HOME}/.lv2"
target_clap_dir="${HOME}/.clap"
target_audio_assault_root="${HOME}/Audio Assault/PluginData/Audio Assault"

cleanup() {
  rm -rf "${workdir}"
}

has_format() {
  local format="$1"
  [[ ",${formats}," == *",${format},"* ]]
}

extract_zip() {
  local archive="$1"
  local destination="$2"

  mkdir -p "${destination}"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "${archive}" -d "${destination}"
    return
  fi

  if command -v 7z >/dev/null 2>&1; then
    7z x -y "-o${destination}" "${archive}" >/dev/null
    return
  fi

  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "${archive}" -C "${destination}"
    return
  fi

  echo "Need one of: unzip, 7z, or bsdtar to unpack ZIP archives." >&2
  exit 1
}

copy_bundle_dir() {
  local source="$1"
  local destination_root="$2"
  local name
  name="$(basename "${source}")"

  mkdir -p "${destination_root}"
  rm -rf "${destination_root:?}/${name}"
  cp -a "${source}" "${destination_root}/"
}

find_bundle_dirs() {
  local root="$1"
  local suffix="$2"

  find "${root}" \
    -type d \
    -name "*.${suffix}" \
    ! -path '*/__MACOSX/*' \
    -print0
}

find_plugin_files() {
  local root="$1"
  local suffix="$2"

  find "${root}" \
    -type f \
    -name "*.${suffix}" \
    ! -path '*/__MACOSX/*' \
    -print0
}

copy_plugin_file() {
  local source="$1"
  local destination_root="$2"

  mkdir -p "${destination_root}"
  install -m755 "${source}" "${destination_root}/$(basename "${source}")"
}

clean_macos_metadata() {
  local destination_root="$1"
  find "${destination_root}" -name '.DS_Store' -type f -delete 2>/dev/null || true
  find "${destination_root}" -name '._*' -type f -delete 2>/dev/null || true
  find "${destination_root}" -name '__MACOSX' -type d -prune -exec rm -rf {} + 2>/dev/null || true
}

copy_data_tree() {
  local source="$1"
  local destination_root="$2"

  mkdir -p "$(dirname "${destination_root}")"
  rm -rf "${destination_root}"
  mkdir -p "${destination_root}"
  cp -a "${source}/." "${destination_root}/"
  clean_macos_metadata "${destination_root}"
}

trap cleanup EXIT

echo "Downloading ${display_name}..."
curl -fL --retry 3 --retry-delay 2 -o "${archive_path}" "${url}"
extract_zip "${archive_path}" "${extract_dir}"

if has_format "clap"; then
  mkdir -p "${target_clap_dir}"
  while IFS= read -r -d '' clap_file; do
    copy_plugin_file "${clap_file}" "${target_clap_dir}"
  done < <(find_plugin_files "${extract_dir}" "clap")
fi

if has_format "vst3"; then
  mkdir -p "${target_vst3_dir}"
  while IFS= read -r -d '' vst3_bundle; do
    copy_bundle_dir "${vst3_bundle}" "${target_vst3_dir}"
  done < <(find_bundle_dirs "${extract_dir}" "vst3")
fi

if has_format "lv2"; then
  mkdir -p "${target_lv2_dir}"
  while IFS= read -r -d '' lv2_bundle; do
    copy_bundle_dir "${lv2_bundle}" "${target_lv2_dir}"
  done < <(find_bundle_dirs "${extract_dir}" "lv2")
fi

if has_format "vst"; then
  mkdir -p "${target_vst_dir}"
  while IFS= read -r -d '' vst2_file; do
    copy_plugin_file "${vst2_file}" "${target_vst_dir}"
  done < <(
    find "${extract_dir}" \
      -type f \
      -name '*.so' \
      ! -path '*/Contents/*' \
      ! -path '*/.lv2/*' \
      -print0
  )
fi

echo "${display_name} installed into:"
if has_format "clap"; then
  echo "  ${target_clap_dir}"
fi
if has_format "vst3"; then
  echo "  ${target_vst3_dir}"
fi
if has_format "lv2"; then
  echo "  ${target_lv2_dir}"
fi
if has_format "vst"; then
  echo "  ${target_vst_dir}"
fi

if has_format "clap" && [[ ! -e "${target_clap_dir}/${primary_bundle_name}.clap" ]]; then
  echo "Warning: expected CLAP file ${primary_bundle_name}.clap was not found after install." >&2
fi
if has_format "vst3" && [[ ! -e "${target_vst3_dir}/${primary_bundle_name}.vst3" ]]; then
  echo "Warning: expected VST3 bundle ${primary_bundle_name}.vst3 was not found after install." >&2
fi
if has_format "lv2" && [[ ! -e "${target_lv2_dir}/${primary_bundle_name}.lv2" ]]; then
  echo "Warning: expected LV2 bundle ${primary_bundle_name}.lv2 was not found after install." >&2
fi

# this is a post installation step specifically to route Audio Assault data packs
if [[ -n "${data_dir_name}" ]]; then
  data_source="$(find "${extract_dir}" -type d -name "${data_dir_name}" | head -n 1 || true)"
  data_target="${target_audio_assault_root}/${data_target_name}"
  if [[ -n "${data_source}" ]]; then
    copy_data_tree "${data_source}" "${data_target}"
    echo "  ${data_target}"
  else
    echo "Warning: expected data directory ${data_dir_name} was not found after install." >&2
  fi
fi
