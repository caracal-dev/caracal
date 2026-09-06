# ── Audio ─────────────────────────────────────────────────────────────────────

# Restart PipeWire (useful after config changes or audio glitches)
[group("audio")]
restart-pipewire:
    echo "Restarting PipeWire..."
    systemctl --user restart pipewire.service

# Switch USB audio interfaces to PipeWire Pro Audio profiles for DAWs.
[group("audio")]
setup-audio-profiles ACTION="":
    #!/usr/bin/env bash
    /usr/libexec/caracal-setup-audio-profiles "{{ ACTION }}"

# Expose JACK D-Bus compatibility for legacy JACK controllers.
[group("audio")]
use-legacy-audio ACTION="":
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    if [[ $(id -u) -eq 0 ]]; then
        echo "Please run 'ujust use-legacy-audio' as your regular user, not root."
        exit 1
    fi

    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust use-legacy-audio <option>"
        echo "  start   Enable and start JACK D-Bus compatibility"
        echo "  remove  Disable and remove JACK D-Bus compatibility"
        exit 0
    elif [[ "$OPTION" == "" ]]; then
        OPTION="start"
    fi

    service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    service_file="$service_dir/caracal-jackdbus.service"

    if [[ "${OPTION,,}" =~ ^(start|enable)$ ]]; then
        if ! command -v jackdbus >/dev/null 2>&1; then
            echo "jackdbus is not installed. Install jack-audio-connection-kit-dbus and try again." >&2
            exit 1
        fi

        mkdir -p "$service_dir"
        cat > "$service_file" <<'EOF'
    [Unit]
    Description=Caracal legacy JACK D-Bus compatibility
    After=pipewire.service wireplumber.service
    Wants=pipewire.service wireplumber.service

    [Service]
    Type=simple
    ExecStart=/usr/bin/jackdbus auto
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=default.target
    EOF

        systemctl --user daemon-reload
        systemctl --user enable --now caracal-jackdbus.service
        echo "Legacy JACK D-Bus compatibility is enabled."
        echo "Legacy controllers can query JACK sample rate, buffer size, and Xrun data through jackdbus."
    elif [[ "${OPTION,,}" =~ ^(remove|disable)$ ]]; then
        systemctl --user disable --now caracal-jackdbus.service 2>/dev/null || true
        rm -f "$service_file"
        systemctl --user daemon-reload
        echo "Legacy JACK D-Bus compatibility removed."
    else
        echo "Unknown option: $OPTION" >&2
        echo "Run 'ujust use-legacy-audio help' for usage."
        exit 1
    fi

# Reapply and report CPU performance mode for low-latency DAWs
[group("audio")]
cpu-performance:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo systemctl restart caracal-cpu-performance.service

    shopt -s nullglob
    governor_paths=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor)
    preference_paths=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference)

    if ((${#governor_paths[@]})); then
        printf 'CPU governors: '
        for path in "${governor_paths[@]}"; do
            [[ -r "$path" ]] && printf '%s\n' "$(<"$path")"
        done | sort -u | paste -sd ', ' -
    else
        echo 'CPU governors: unavailable'
    fi

    if ((${#preference_paths[@]})); then
        printf 'Energy preferences: '
        for path in "${preference_paths[@]}"; do
            [[ -r "$path" ]] && printf '%s\n' "$(<"$path")"
        done | sort -u | paste -sd ', ' -
    fi

# Toggle Bluetooth headset profile mitigation. When enabled, prevents automatic
# switch to low-quality HFP/HSP profile — keeps A2DP (high quality) at all times.

# Disable to restore headset mic functionality.
[group("audio")]
toggle-bt-mic:
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    CONFIG_FILE="/etc/wireplumber/wireplumber.conf.d/51-mitigate-annoying-profile-switch.conf"
    CURRENT_STATE="Disabled"
    if [ -f "$CONFIG_FILE" ]; then
        CURRENT_STATE="Enabled"
    fi
    echo "Bluetooth headset profile mitigation is currently: ${bold}${CURRENT_STATE}${normal}"
    OPTION=$(Choose Enable Disable)
    if [[ "${OPTION,,}" == "enable" ]]; then
        sudo mkdir -p "$(dirname "$CONFIG_FILE")"
        printf '%s\n' \
            'wireplumber.settings = {' \
            '  bluetooth.autoswitch-to-headset-profile = false' \
            '}' \
            '' \
            'monitor.bluez.properties = {' \
            '  bluez5.roles = [ a2dp_sink a2dp_source ]' \
            '}' \
            | sudo tee "$CONFIG_FILE" > /dev/null
        systemctl --user restart wireplumber
        echo "Mitigation ${green}${bold}enabled${normal} — BT device will stay on A2DP. Headset mic disabled."
    elif [[ "${OPTION,,}" == "disable" ]]; then
        if sudo rm -f "$CONFIG_FILE"; then
            systemctl --user restart wireplumber
            echo "Mitigation ${red}${bold}disabled${normal} — BT headset profile switching restored."
        else
            echo "Failed to remove config. Check sudo permissions."
        fi
    fi

# Set up named PipeWire loopback sinks for flexible audio routing in your DAW,
# patchbay (qpwgraph / Helvum / Carla), or for separating streams to different outputs.

# Creates four sinks: DAW, Monitoring, Recording, System
[group("audio")]
setup-virtual-channels ACTION="":
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    mkdir -p ~/.config/pipewire/pipewire.conf.d
    OPTION="{{ ACTION }}"
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust setup-virtual-channels <option>"
        echo "  Use 'create' to create virtual audio channels"
        echo "  Use 'remove' to remove virtual audio channels"
        exit 0
    elif [ "$OPTION" == "" ]; then
        echo "${bold}Virtual Audio Channels${normal}"
        OPTION=$(Choose "Create virtual channels" "Remove virtual channels")
    fi
    if [[ "${OPTION,,}" =~ ^create ]]; then
        printf '%s\n' \
            'context.modules = [' \
            '    { name = libpipewire-module-loopback' \
            '        args = {' \
            '            node.description = "DAW"' \
            '            capture.props = {' \
            '                node.name      = "sink.daw"' \
            '                media.class    = "Audio/Sink"' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '            playback.props = {' \
            '                node.name    = "playback.daw"' \
            '                node.passive = true' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '        }' \
            '    }' \
            '    { name = libpipewire-module-loopback' \
            '        args = {' \
            '            node.description = "Monitoring"' \
            '            capture.props = {' \
            '                node.name      = "sink.monitoring"' \
            '                media.class    = "Audio/Sink"' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '            playback.props = {' \
            '                node.name    = "playback.monitoring"' \
            '                node.passive = true' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '        }' \
            '    }' \
            '    { name = libpipewire-module-loopback' \
            '        args = {' \
            '            node.description = "Recording"' \
            '            capture.props = {' \
            '                node.name      = "sink.recording"' \
            '                media.class    = "Audio/Sink"' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '            playback.props = {' \
            '                node.name    = "playback.recording"' \
            '                node.passive = true' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '        }' \
            '    }' \
            '    { name = libpipewire-module-loopback' \
            '        args = {' \
            '            node.description = "System"' \
            '            capture.props = {' \
            '                node.name      = "sink.system"' \
            '                media.class    = "Audio/Sink"' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '            playback.props = {' \
            '                node.name    = "playback.system"' \
            '                node.passive = true' \
            '                audio.position = [ FL FR ]' \
            '            }' \
            '        }' \
            '    }' \
            ']' \
            > ~/.config/pipewire/pipewire.conf.d/virtual-channels.conf
        echo "Virtual channels created: DAW, Monitoring, Recording, System"
        echo "Log out and back in (or run ujust restart-pipewire) for them to appear."
        echo "Route them in qpwgraph, Helvum, or Carla."
    elif [[ "${OPTION,,}" =~ ^remove ]]; then
        rm -f ~/.config/pipewire/pipewire.conf.d/virtual-channels.conf
        echo "Virtual channels removed. Log out or run ujust restart-pipewire to apply."
    fi

# Add legacy MIDI channels to JACK/PipeWire patchbays.
[group("audio")]
add-legacy-channels ACTION="":
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    if [[ $(id -u) -eq 0 ]]; then
        echo "Please run 'ujust add-legacy-channels' as your regular user, not root."
        exit 1
    fi

    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust add-legacy-channels <option>"
        echo "  a2j     Enable ALSA-to-JACK MIDI bridge with hardware export"
        echo "  native  Enable PipeWire native ALSA sequencer MIDI bridge"
        echo "  remove  Disable Caracal legacy MIDI bridge setup"
        exit 0
    elif [[ "$OPTION" == "" ]]; then
        OPTION="a2j"
    fi

    systemd_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    a2j_service="$systemd_dir/caracal-a2jmidid.service"
    pipewire_dir="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d"
    native_config="$pipewire_dir/legacy-midi-bridge.conf"

    if [[ "${OPTION,,}" =~ ^(a2j|alsa-to-jack) ]]; then
        if ! command -v a2jmidid >/dev/null 2>&1; then
            echo "a2jmidid is not installed. Install a2jmidid and try again." >&2
            exit 1
        fi

        mkdir -p "$systemd_dir"
        cat > "$a2j_service" <<'EOF'
    [Unit]
    Description=Caracal ALSA-to-JACK MIDI bridge
    After=pipewire.service wireplumber.service caracal-jackdbus.service
    Wants=pipewire.service wireplumber.service

    [Service]
    Type=simple
    ExecStart=/usr/bin/a2jmidid -e
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=default.target
    EOF

        rm -f "$native_config"
        systemctl --user daemon-reload
        systemctl --user enable --now caracal-a2jmidid.service
        echo "ALSA-to-JACK MIDI bridge enabled with hardware export."
        echo "Legacy MIDI hardware and software should appear in JACK/PipeWire patchbays."
    elif [[ "${OPTION,,}" =~ ^native ]]; then
        mkdir -p "$pipewire_dir"
        cat > "$native_config" <<'EOF'
    context.objects = [
        { factory = spa-node-factory
            args = {
                factory.name     = api.alsa.seq.bridge
                node.name        = "Midi-Bridge"
                node.description = "MIDI Bridge"
                media.class      = "Midi/Bridge"
            }
        }
    ]
    EOF

        systemctl --user disable --now caracal-a2jmidid.service 2>/dev/null || true
        rm -f "$a2j_service"
        systemctl --user daemon-reload
        systemctl --user restart pipewire.service
        echo "Native PipeWire MIDI bridge enabled."
        echo "Legacy MIDI hardware and software should appear in PipeWire patchbays."
    elif [[ "${OPTION,,}" =~ ^(remove|disable) ]]; then
        systemctl --user disable --now caracal-a2jmidid.service 2>/dev/null || true
        rm -f "$a2j_service" "$native_config"
        systemctl --user daemon-reload
        systemctl --user restart pipewire.service
        echo "Legacy MIDI bridge setup removed."
    else
        echo "Unknown option: $OPTION" >&2
        echo "Run 'ujust add-legacy-channels help' for usage."
        exit 1
    fi

# Check and update firmware for audio interfaces, MIDI controllers, and
# other hardware supported by the LVFS (Linux Vendor Firmware Service).
# Runs fwupdmgr refresh to fetch latest metadata, then lists available
# updates.
[group("audio")]
update-audio-firmware:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v fwupdmgr >/dev/null 2>&1; then
        echo "fwupdmgr is not installed. Install fwupd and try again."
        exit 1
    fi
    echo "Refreshing firmware metadata from LVFS..."
    sudo fwupdmgr refresh --no-unavailable 2>/dev/null || true
    echo ""
    echo "Checking for available firmware updates..."
    updates="$(fwupdmgr get-updates 2>/dev/null || true)"
    if echo "$updates" | grep -qi "no updates"; then
        echo "All firmware is up to date."
    else
        echo "$updates"
        echo ""
        echo "To install all available updates, run:"
        echo "  sudo fwupdmgr update"
    fi
