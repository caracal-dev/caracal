#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <primary-bundle-name> <formats> [data-target-name]" >&2
    exit 1
fi

primary_bundle_name="$1"
formats="$2"
data_target_name="${3:-}"

has_format() {
    local format="$1"
    [[ ",${formats}," == *",${format},"* ]]
}

if has_format "clap"; then
    rm -f "${HOME}/.clap/${primary_bundle_name}.clap"
fi
if has_format "vst3"; then
    rm -rf "${HOME}/.vst3/${primary_bundle_name}.vst3"
fi
if has_format "lv2"; then
    rm -rf "${HOME}/.lv2/${primary_bundle_name}.lv2"
fi
if has_format "vst"; then
    rm -f "${HOME}/.vst/lib${primary_bundle_name}.so"
    rm -f "${HOME}/.vst/${primary_bundle_name}.so"
fi

if [[ -n "${data_target_name}" ]]; then
    rm -rf "${HOME}/Audio Assault/PluginData/AudioAssault/${data_target_name}"
fi

echo "${primary_bundle_name} removed."
