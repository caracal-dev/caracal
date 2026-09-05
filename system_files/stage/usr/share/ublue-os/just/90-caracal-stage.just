# Caracal Stage focused setup recipes.

default:
    @just --list

stage:
    caracal-stage

restart-pipewire:
    systemctl --user restart pipewire.service wireplumber.service pipewire-pulse.service

setup-audio-profiles ACTION="":
    #!/usr/bin/env bash
    /usr/libexec/caracal-setup-audio-profiles "{{ ACTION }}"

first-run:
    #!/usr/bin/env bash
    set -euo pipefail

    target_user="${SUDO_USER:-$(logname 2>/dev/null || id -un)}"
    if [[ -z "$target_user" ]] || [[ "$target_user" == "root" ]]; then
        echo "Run ujust first-run as your regular user, not root." >&2
        exit 1
    fi

    # caracal-stage-firstboot already places ISO-installed users in these groups.
    # Only escalate when something is actually missing so this recipe also runs
    # non-interactively from caracal-stage-first-run.service (no tty for sudo).
    # audio + realtime back the rtprio/memlock limits in limits.d. pipewire is
    # deliberately omitted: it is unused on modern PipeWire and would never show
    # in `id -nG`, forcing a pointless sudo on every run.
    current_groups="$(id -nG "$target_user")"
    for grp in audio realtime; do
        if ! grep -qw "$grp" <<<"$current_groups"; then
            sudo getent group "$grp" >/dev/null || sudo groupadd -r "$grp"
            sudo usermod -aG "$grp" "$target_user"
        fi
    done

    ujust setup-audio-profiles apply || true

    ujust yabridge-setup

    mkdir -p ~/.vst3 ~/.lv2 ~/.clap ~/.vst
    cp -rn -u /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn -u /usr/lib64/vst/* ~/.vst/ 2>/dev/null || true
    cp -rn -u /usr/lib64/lv2/* ~/.lv2/ 2>/dev/null || true
    cp -rn -u /usr/lib64/clap/* ~/.clap/ 2>/dev/null || true

    echo "Added ${target_user} to audio/realtime and prepared Wine/Yabridge plugin folders."
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

    source /usr/share/caracal/version-pins
    export WINELOADER="${wine_loader}"
    wine_version="$("$WINELOADER" --version 2>/dev/null || true)"
    if [[ "${wine_version}" != wine-${STAGE_WINE_VERSION}* ]]; then
        echo "Expected Patrickl's wine-staging-dev Wine ${STAGE_WINE_VERSION} stack, got '${wine_version:-unknown}'." >&2
        exit 1
    fi

    "$wine_boot" -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir"
    yabridgectl add "$vst3_dir"
    yabridgectl sync

# Auto-connect Carla plugin JACK ports to the default audio sink/source.
# Run this after adding plugins in Carla to wire them to your interface.
carla-connect:
    #!/usr/bin/env bash
    set -euo pipefail

    if ! command -v pw-link &>/dev/null; then
        echo "PipeWire (pw-link) not found; can't route audio." >&2
        exit 1
    fi

    # Get default audio sink and source port lists
    sink_ports=($(pw-link -i | grep "^alsa_output.*playback" | sort))
    source_ports=($(pw-link -o | grep "^alsa_input.*capture" | sort))

    if [[ ${#sink_ports[@]} -eq 0 ]]; then
        echo "No ALSA playback sink found; is your interface connected?" >&2
        exit 1
    fi

    # Build set of already-connected ports from pw-link --links
    declare -A connected_out connected_in
    current_header=""
    links="$(pw-link --links 2>/dev/null || true)"
    while IFS= read -r line; do
        trimmed="${line#"${line%%[! ]*}"}"
        [[ -z "$trimmed" ]] && continue
        if [[ "$line" == "$trimmed" ]]; then
            current_header="$trimmed"
        elif [[ "$trimmed" == "|->"* ]]; then
            target="${trimmed#|-> }"
            connected_out["$current_header"]=1
            connected_in["$target"]=1
        elif [[ "$trimmed" == "|<-"* ]]; then
            source="${trimmed#|<- }"
            connected_in["$current_header"]=1
            connected_out["$source"]=1
        fi
    done <<< "$links"

    plugin_outputs=()
    plugin_inputs=()
    outputs="$(pw-link -o)"
    while IFS= read -r port; do
        [[ -z "$port" ]] && continue
        case "$port" in
            alsa_*|Midi-*|bluez_*|raop_*|Zen:*) continue ;;
        esac
        case "$port" in
            *:monitor_*) continue ;;
            *:events-in) continue ;;
        esac
        if [[ -z "${connected_out[$port]:-}" ]]; then
            plugin_outputs+=("$port")
        fi
    done <<< "$outputs"
    inputs="$(pw-link -i)"
    while IFS= read -r port; do
        [[ -z "$port" ]] && continue
        case "$port" in
            alsa_*|Midi-*|bluez_*|raop_*|Zen:*) continue ;;
        esac
        case "$port" in
            *:monitor_*) continue ;;
            *:events-in) continue ;;
        esac
        if [[ -z "${connected_in[$port]:-}" ]]; then
            plugin_inputs+=("$port")
        fi
    done <<< "$inputs"

    connected=0

    # Route plugin outputs to the default sink (first stereo pair)
    if [[ ${#plugin_outputs[@]} -gt 0 ]]; then
        echo "Connecting ${#plugin_outputs[@]} plugin output(s) to sink..."
        sink_idx=0
        for out_port in "${plugin_outputs[@]}"; do
            sink_port="${sink_ports[$sink_idx]}"
            if [[ -z "$sink_port" ]]; then
                sink_idx=0
                sink_port="${sink_ports[$sink_idx]}"
            fi
            if pw-link "$out_port" "$sink_port" 2>/dev/null; then
                echo "  $out_port -> $sink_port"
                ((connected++))
            fi
            sink_idx=$(( (sink_idx + 1) % ${#sink_ports[@]} ))
        done
    fi

    # Route source (interface input) to plugin inputs
    if [[ ${#plugin_inputs[@]} -gt 0 ]]; then
        echo "Connecting ${#plugin_inputs[@]} plugin input(s) from source..."
        src_idx=0
        for in_port in "${plugin_inputs[@]}"; do
            src_port="${source_ports[$src_idx]}"
            if [[ -z "$src_port" ]]; then
                src_idx=0
                src_port="${source_ports[$src_idx]}"
            fi
            if pw-link "$src_port" "$in_port" 2>/dev/null; then
                echo "  $src_port -> $in_port"
                ((connected++))
            fi
            src_idx=$(( (src_idx + 1) % ${#source_ports[@]} ))
        done
    fi

    if [[ $connected -eq 0 ]]; then
        echo "No unconnected Carla plugin ports found. Is Carla running with loaded plugins?"
        echo "Check with: pw-link -io | grep -v 'alsa_\|Midi-\|bluez\|raop\|Zen'"
    else
        echo "Done: $connected connection(s) established."
    fi
