# Caracal Stage focused setup recipes.

default:
    @just --list

stage:
    caracal-stage

restart-pipewire:
    systemctl --user restart pipewire.service wireplumber.service pipewire-pulse.service

first-run:
    #!/usr/bin/env bash
    set -euo pipefail

    target_user="${SUDO_USER:-$(logname 2>/dev/null || id -un)}"
    if [[ -z "$target_user" ]] || [[ "$target_user" == "root" ]]; then
        echo "Run ujust first-run as your regular user, not root." >&2
        exit 1
    fi

    sudo getent group audio >/dev/null || sudo groupadd -r audio
    sudo getent group realtime >/dev/null || sudo groupadd -r realtime
    sudo usermod -aG audio,realtime,pipewire "$target_user"

    ujust yabridge-setup

    mkdir -p ~/.vst3 ~/.lv2 ~/.clap ~/.vst
    cp -rn -u /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn -u /usr/lib64/vst/* ~/.vst/ 2>/dev/null || true
    cp -rn -u /usr/lib64/lv2/* ~/.lv2/ 2>/dev/null || true
    cp -rn -u /usr/lib64/clap/* ~/.clap/ 2>/dev/null || true

    echo "Added ${target_user} to audio/realtime/pipewire and prepared Wine/Yabridge plugin folders."
    echo "Log out and back in before starting the stage session."

yabridge-sync:
    yabridgectl sync

yabridge-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    wine_loader=""
    for loader in wine wine64 /usr/bin/wine /usr/bin/wine64 /usr/sbin/wine /usr/sbin/wine64 /opt/wine-tkg/bin/wine /opt/wine-tkg/bin/wine64; do
        if command -v "$loader" &>/dev/null; then
            wine_loader="$(command -v "$loader")"
            break
        elif [[ -x "$loader" ]]; then
            wine_loader="$loader"
            break
        fi
    done

    wine_boot=""
    for boot in wineboot /usr/bin/wineboot /usr/sbin/wineboot /opt/wine-tkg/bin/wineboot; do
        if command -v "$boot" &>/dev/null; then
            wine_boot="$(command -v "$boot")"
            break
        elif [[ -x "$boot" ]]; then
            wine_boot="$boot"
            break
        fi
    done

    if [[ -z "${wine_loader}" || -z "${wine_boot}" ]]; then
        echo "Wine loader or wineboot not found." >&2
        rpm -q wine wine-core wine-common yabridge winetricks 2>/dev/null || true
        exit 1
    fi

    export WINELOADER="${wine_loader}"
    wine_version="$("$WINELOADER" --version 2>/dev/null || true)"
    if [[ "${wine_version}" != wine-11.8* ]]; then
        echo "Expected Patrickl's Juce 8 Wine 11.8 stack, got '${wine_version:-unknown}'." >&2
        exit 1
    fi

    "$wine_boot" -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir"
    yabridgectl add "$vst3_dir"
    yabridgectl sync
