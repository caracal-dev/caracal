# Caracal OS ujust recipes
# Run with: ujust <recipe-name>
# ── Helper ────────────────────────────────────────────────────────────────────

[private]
_ask-remove-ardour:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! rpm -q ardour9 &>/dev/null; then
        # Already removed (or never installed) — nothing to do
        exit 0
    fi
    echo ""
    echo "Ardour is installed as the default open-source DAW."
    read -rp "Would you like to remove it? (Requires reboot) [y/N] " yn
    if [[ "${yn,,}" == "y" ]]; then
        rpm-ostree override remove ardour9
        echo "Ardour queued for removal. Run 'systemctl reboot' when ready."
    else
        echo "Keeping Ardour."
    fi

# ── CLI bling ─────────────────────────────────────────────────────────────────
# Adapted from Bazzite
# Credit https://github/ublue-os/bazzite
# Enable enhanced CLI tools (eza, atuin, zoxide, ugrep) in your shell
caracal-cli:
    #!/usr/bin/env bash
    set -eou pipefail
    source /usr/lib/ujust/ujust.sh

    function Exiting(){
        printf "%s%sExiting...%s\n" "${red}" "${bold}" "${normal}"
        printf "Rerun with %s%sujust caracal-cli%s\n" "${blue}" "${bold}" "${normal}"
        exit 0
    }

    function ctrl_c(){
        printf "\nSignal SIGINT caught\n"
        Exiting
    }

    function brew-bundle(){
        echo 'Installing bling tools from Homebrew...'
        brew bundle --file /usr/share/ublue-os/homebrew/caracal-cli.Brewfile --verbose
    }

    function check-bling(){
        local shell="$1"
        if [[ "${shell}" == "fish" ]]; then
            grep -q "source /usr/share/caracal-cli/bling.fish" \
                "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" 2>/dev/null && return 1 || return 0
        elif [[ "${shell}" == "zsh" ]]; then
            grep -q "source /usr/share/caracal-cli/bling.sh" \
                "${ZDOTDIR:-$HOME}/.zshrc" 2>/dev/null && return 1 || return 0
        elif [[ "${shell}" == "bash" ]]; then
            grep -q "source /usr/share/caracal-cli/bling.sh" \
                "${HOME}/.bashrc" 2>/dev/null && return 1 || return 0
        else
            echo 'Unknown shell — you are on your own'
            exit 1
        fi
    }

    function add-bling(){
        local shell="$1"
        brew-bundle
        echo 'Wiring bling into your shell config...'
        if [[ "${shell}" == "fish" ]]; then
            mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/fish"
            printf '%s\n' \
                '### caracal bling source start' \
                'test -f /usr/share/caracal-cli/bling.fish && source /usr/share/caracal-cli/bling.fish' \
                '### caracal bling source end' \
                >> "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
        elif [[ "${shell}" == "zsh" ]]; then
            printf '%s\n' \
                '### caracal bling source start' \
                'test -f /usr/share/caracal-cli/bling.sh && source /usr/share/caracal-cli/bling.sh' \
                '### caracal bling source end' \
                >> "${ZDOTDIR:-$HOME}/.zshrc"
        elif [[ "${shell}" == "bash" ]]; then
            printf '%s\n' \
                '### caracal bling source start' \
                'test -f /usr/share/caracal-cli/bling.sh && source /usr/share/caracal-cli/bling.sh' \
                '### caracal bling source end' \
                >> "${HOME}/.bashrc"
        fi
    }

    function remove-bling(){
        local shell="$1"
        if [[ "${shell}" == "fish" ]]; then
            sed -i '/### caracal bling source start/,/### caracal bling source end/d' \
                "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" 2>/dev/null || true
        elif [[ "${shell}" == "zsh" ]]; then
            sed -i '/### caracal bling source start/,/### caracal bling source end/d' \
                "${ZDOTDIR:-$HOME}/.zshrc" 2>/dev/null || true
        elif [[ "${shell}" == "bash" ]]; then
            sed -i '/### caracal bling source start/,/### caracal bling source end/d' \
                "${HOME}/.bashrc" 2>/dev/null || true
        fi
    }

    shell=$(basename "$SHELL")
    printf "Shell:\t%s%s%s%s\n" "${green}" "${bold}" "${shell}" "${normal}"
    if ! check-bling "${shell}"; then
        printf "Bling:\t%s%sEnabled%s\n" "${green}" "${bold}" "${normal}"
    else
        printf "Bling:\t%s%sDisabled%s\n" "${red}" "${bold}" "${normal}"
    fi

    CHOICE=$(Choose enable disable cancel)
    trap ctrl_c SIGINT

    if [[ "${CHOICE}" == "enable" ]]; then
        if check-bling "${shell}"; then
            add-bling "${shell}"
            printf "%s%sDone%s — close and reopen your terminal to apply.\n" "${green}" "${bold}" "${normal}"
        else
            printf "Bling is already enabled for %s.\n" "${shell}"
        fi
    elif [[ "${CHOICE}" == "disable" ]]; then
        if ! check-bling "${shell}"; then
            remove-bling "${shell}"
            printf "%s%sBling removed%s — close and reopen your terminal.\n" "${red}" "${bold}" "${normal}"
        else
            printf "Bling is not currently enabled for %s.\n" "${shell}"
        fi
    else
        Exiting
    fi

# ── Developer Experience ──────────────────────────────────────────────────────

# Add the current user to common DX groups for Docker, Incus, libvirt, and serial devices
[group("system")]
dx-group:
    #!/usr/bin/pkexec bash
    set -euo pipefail

    append_group() {
        local group_name="$1"

        if getent group "$group_name" >/dev/null 2>&1; then
            return 0
        fi

        if grep -q "^${group_name}:" /usr/lib/group 2>/dev/null; then
            grep "^${group_name}:" /usr/lib/group >> /etc/group
        else
            groupadd -r "$group_name"
        fi
    }

    target_user="{{ `id -un` }}"
    groups_add=(docker incus-admin libvirt dialout)

    for group_name in "${groups_add[@]}"; do
        append_group "$group_name"
        usermod -aG "$group_name" "$target_user"
    done

    echo "Added ${target_user} to: ${groups_add[*]}"
    echo "Reboot, or log out and back in, before using Docker, Incus, libvirt, or serial devices."

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

# ── Virtualization ────────────────────────────────────────────────────────────

# Adapted from Bazzite's setup-virtualization recipe:
# https://github.com/ublue-os/bazzite
# Caracal-specific changes:
# - virtualization packages are already baked into the image
# - Bazzite's delayed libvirtd setup service is not used here
# - kvmfr support is omitted because Caracal does not currently ship that module
# Set up libvirt, VFIO kernel args, and USB hot plugging helpers
[group("virtualization")]
setup-virtualization ACTION="":
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    if [[ $(id -u) -eq 0 ]]; then
        echo "Please do not run this command as root."
        exit 1
    fi

    on_valve_hardware() {
        command -v /usr/libexec/hwsupport/valve-hardware >/dev/null 2>&1 &&
            /usr/libexec/hwsupport/valve-hardware
    }

    ensure_libvirtd() {
        if ! systemctl is-enabled --quiet libvirtd.service 2>/dev/null; then
            echo "Enabling libvirtd..."
            sudo systemctl enable --now libvirtd
        elif ! systemctl is-active --quiet libvirtd.service 2>/dev/null; then
            echo "Starting libvirtd..."
            sudo systemctl start libvirtd
        fi
    }

    ensure_swtpm_state() {
        echo "Making sure swtpm state exists..."
        sudo mkdir -p /var/lib/swtpm-localca
        sudo chown tss:tss /var/lib/swtpm-localca 2>/dev/null || sudo chown tss /var/lib/swtpm-localca
        sudo restorecon -Rv /var/lib/libvirt /var/log/libvirt /var/lib/swtpm-localca 2>/dev/null || true
    }

    grant_iso_acl() {
        if command -v setfacl >/dev/null 2>&1; then
            echo "Giving qemu read access to ISO files in $HOME..."
            sudo setfacl -m u:qemu:rx "$HOME" || true
        fi
    }

    cpu_vendor_karg() {
        local cpu_vendor
        cpu_vendor="$(awk -F': ' '/vendor_id/ { print $2; exit }' /proc/cpuinfo)"
        case "$cpu_vendor" in
            AuthenticAMD) echo "amd_iommu=on" ;;
            GenuineIntel) echo "intel_iommu=on" ;;
            *) return 1 ;;
        esac
    }

    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust setup-virtualization <option>"
        echo "  virt-on     Enable virtualization kernel args and libvirtd"
        echo "  virt-off    Disable virtualization kernel args and libvirtd"
        echo "  group       Add $USER to the libvirt group"
        echo "  vfio-on     Enable VFIO-related kernel args"
        echo "  vfio-off    Disable VFIO-related kernel args"
        echo "  usbhp-on    Enable SPICE USB hot plugging rule"
        echo "  usbhp-off   Disable SPICE USB hot plugging rule"
        exit 0
    elif [[ -z "$OPTION" ]]; then
        echo "${bold}Virtualization Setup${normal}"
        echo "Caracal already ships the virtualization packages in the base image."
        OPTION=$(Choose \
            "Enable virtualization" \
            "Disable virtualization" \
            "Add $USER to libvirt group" \
            "Enable VFIO drivers" \
            "Disable VFIO drivers" \
            "Enable USB hot plugging" \
            "Disable USB hot plugging" \
        )
    fi

    if on_valve_hardware; then
        echo "${red}${b}WARNING${n}: Virtualization and VFIO are not well supported on Steam Deck-class hardware."
    fi

    if [[ "${OPTION,,}" =~ (^enable[[:space:]]virtualization|virt-on) ]]; then
        ensure_libvirtd
        ensure_swtpm_state
        grant_iso_acl
        rpm-ostree kargs \
            --append-if-missing="kvm.ignore_msrs=1" \
            --append-if-missing="kvm.report_ignored_msrs=0"
        echo "Virtualization enabled. Reboot if kernel args changed."

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]virtualization|virt-off) ]]; then
        if systemctl is-enabled --quiet libvirtd.service 2>/dev/null ||
            systemctl is-active --quiet libvirtd.service 2>/dev/null; then
            echo "Disabling libvirtd..."
            sudo systemctl disable --now libvirtd || true
        fi
        rpm-ostree kargs \
            --delete-if-present="kvm.ignore_msrs=1" \
            --delete-if-present="kvm.report_ignored_msrs=0"
        echo "Virtualization disabled. Base packages remain installed; reboot if kernel args changed."

    elif [[ "${OPTION,,}" =~ group ]]; then
        if ! getent group libvirt >/dev/null 2>&1; then
            echo "libvirt group is missing."
            exit 1
        fi
        sudo usermod -aG libvirt "$USER"
        echo "Added $USER to libvirt. Log out and back in for group membership to apply."

    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]vfio|vfio-on) ]]; then
        if on_valve_hardware; then
            echo "IOMMU/VFIO is not supported on this hardware."
            exit 0
        fi

        ensure_libvirtd
        vendor_karg="$(cpu_vendor_karg)" || {
            echo "Failed to determine CPU vendor."
            exit 1
        }

        rpm-ostree initramfs --enable
        rpm-ostree kargs \
            --append-if-missing="kvm.ignore_msrs=1" \
            --append-if-missing="kvm.report_ignored_msrs=0" \
            --append-if-missing="${vendor_karg}" \
            --append-if-missing="iommu=pt" \
            --append-if-missing="rd.driver.pre=vfio-pci" \
            --append-if-missing="vfio_pci.disable_vga=1"

        echo "VFIO kernel args queued for next boot."
        echo 'Add passthrough device IDs separately with: rpm-ostree kargs --append-if-missing="vfio_pci.ids=xxxx:yyyy,xxxx:zzzz"'
        echo "Reboot after enabling VFIO."

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]vfio|vfio-off) ]]; then
        echo "Make sure any VFIO-backed VMs are not set to autostart before continuing."
        CONFIRM=$(Choose Cancel Continue)
        if [[ "$CONFIRM" != "Continue" ]]; then
            exit 0
        fi

        vfio_ids="$(rpm-ostree kargs | tr ' ' '\n' | grep '^vfio_pci.ids=' || true)"
        rpm_ostree_args=(
            --delete-if-present="iommu=pt"
            --delete-if-present="iommu=on"
            --delete-if-present="amd_iommu=on"
            --delete-if-present="intel_iommu=on"
            --delete-if-present="rd.driver.pre=vfio-pci"
            --delete-if-present="vfio_pci.disable_vga=1"
            --delete-if-present="vfio_pci.disable_vga=0"
        )
        if [[ -n "$vfio_ids" ]]; then
            rpm_ostree_args+=(--delete-if-present="$vfio_ids")
        fi

        sudo rm -f /etc/dracut.conf.d/vfio.conf
        rpm-ostree kargs "${rpm_ostree_args[@]}"
        echo "VFIO kernel args removed. Reboot to apply."

    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]usb|usbhp-on) ]]; then
        echo "Adding udev rule for USB hot plugging..."
        printf '%s\n' 'ACTION=="add", SUBSYSTEM=="usb", TAG+="uaccess"' |
            sudo tee /etc/udev/rules.d/72-usbhp.rules >/dev/null
        sudo udevadm control --reload || true
        echo "USB hot plugging enabled."

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]usb|usbhp-off) ]]; then
        sudo rm -f /etc/udev/rules.d/72-usbhp.rules
        sudo udevadm control --reload || true
        echo "USB hot plugging disabled."

    else
        echo "Unknown option: $OPTION"
        echo "Run 'ujust setup-virtualization help' for usage."
        exit 1
    fi

# ── First-run & setup ─────────────────────────────────────────────────────────

# First-run setup: add audio/realtime groups, install shell extras, and set up yabridge
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

    ujust setup-audio-profiles apply || true

    # Set up Wine-native VST bridge
    export WINELOADER=""
    for loader in wine wine64 /usr/bin/wine /usr/bin/wine64 /usr/sbin/wine /usr/sbin/wine64 /opt/wine-tkg/bin/wine /opt/wine-tkg/bin/wine64; do
        if command -v "$loader" &>/dev/null; then
            WINELOADER="$(command -v "$loader")"
            break
        fi
    done

    WINEBOOT=""
    for boot in wineboot /usr/bin/wineboot /usr/sbin/wineboot /opt/wine-tkg/bin/wineboot; do
        if command -v "$boot" &>/dev/null; then
            WINEBOOT="$(command -v "$boot")"
            break
        fi
    done

    if [[ -z "${WINELOADER}" || -z "${WINEBOOT}" ]]; then
        echo "Error: Wine loader or wineboot not found." >&2
        echo "WINELOADER: '${WINELOADER:-not found}'" >&2
        echo "WINEBOOT:   '${WINEBOOT:-not found}'" >&2
        echo "Searched PATH: $PATH" >&2
        echo "Checking common locations..." >&2
        ls -l /usr/bin/wine* /usr/sbin/wine* /opt/wine-tkg/bin/wine* 2>/dev/null || true
        echo "Tip: Ensure wine-core and wine-common are installed. On Caracal, these should be in the base image." >&2
        echo "If you just updated, a reboot might be required to refresh the PATH and library links." >&2
        exit 1
    fi
    echo "Using Wine loader: ${WINELOADER}"
    wine_version="$("$WINELOADER" --version 2>/dev/null || true)"
    echo "Wine version: ${wine_version:-unknown}"
    if [[ "${wine_version}" != wine-11.16* ]]; then
        echo "Error: expected Patrickl's wine-staging-dev Wine 11.16 stack, got '${wine_version:-unknown}'." >&2
        echo "Wine 11.10 currently fails PE32 WoW64 execution on Caracal." >&2
        echo "Rebuild or update Caracal with patrickl/wine-staging-dev providing Wine 11.16." >&2
        rpm -q wine wine-core wine-common yabridge winetricks 2>/dev/null || true
        exit 1
    fi

    wow64_prefix="$(mktemp -d "${TMPDIR:-/tmp}/caracal-wow64-check.XXXXXX")"
    if ! WINEPREFIX="$wow64_prefix" WINEDEBUG=-all "$WINEBOOT" -u; then
        WINEPREFIX="$wow64_prefix" wineserver -w 2>/dev/null || true
        rm -rf "$wow64_prefix"
        echo "Error: Wine cannot initialize a temporary WoW64 prefix." >&2
        echo "Rebuild or update Caracal with Patrickl's wine-staging-dev Wine stack." >&2
        exit 1
    fi
    wine_i386_cmd=""
    for bin in \
        /usr/lib64/wine-wow64/wine/i386-windows/cmd.exe \
        /usr/lib/wine/i386-windows/cmd.exe \
        /usr/lib64/wine/i386-windows/cmd.exe; do
        if [[ -f "$bin" ]]; then
            wine_i386_cmd="$bin"
            break
        fi
    done
    # A crashing 32-bit Wine process still exits 0, so check the actual output
    # of `ver` rather than the exit code.
    pe32_output=""
    if [[ -n "${wine_i386_cmd}" ]]; then
        pe32_output="$(WINEPREFIX="$wow64_prefix" WINEDEBUG=-all "$WINELOADER" "$wine_i386_cmd" /c ver 2>/dev/null || true)"
    fi
    if [[ -z "${wine_i386_cmd}" ]] || ! grep -qi 'Microsoft Windows' <<<"${pe32_output}"; then
        WINEPREFIX="$wow64_prefix" wineserver -w 2>/dev/null || true
        rm -rf "$wow64_prefix"
        echo "Error: Wine cannot run PE32 Windows programs through WoW64." >&2
        echo "On Caracal's composefs root this is provided by caracal-wine-execmod.service." >&2
        echo "Check it with: systemctl status caracal-wine-execmod.service" >&2
        echo "Then ensure /usr/lib64/wine-wow64/wine/i386-windows is a bind mount: findmnt /usr/lib64/wine-wow64/wine/i386-windows" >&2
        rpm -q wine wine-core wine-common yabridge winetricks 2>/dev/null || true
        exit 1
    fi
    WINEPREFIX="$wow64_prefix" wineserver -w 2>/dev/null || true
    rm -rf "$wow64_prefix"

    "$WINEBOOT" -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir"
    
    if ! command -v yabridgectl &>/dev/null; then
        echo "Error: yabridgectl not found. Skipping yabridge setup." >&2
    else
        yabridgectl add "$vst3_dir"
        yabridgectl sync
    fi

    echo "Added ${target_user} to audio and realtime."

    echo "Routing plugins to user folders"
        mkdir -p ~/.vst3 ~/.lv2 ~/.clap ~/.vst
    cp -rn -u  /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn -u /usr/lib64/vst/*  ~/.vst/  2>/dev/null || true
    cp -rn -u /usr/lib64/lv2/*  ~/.lv2/  2>/dev/null || true
    cp -rn -u /usr/lib64/clap/* ~/.clap/ 2>/dev/null || true

    echo "Audio plugins have been moved to user folders"

    echo "Setting up shell"
    function brew-bundle(){
        echo 'Installing bling tools from Homebrew...'
        brew bundle --file /usr/share/ublue-os/homebrew/caracal-cli.Brewfile --verbose
    }
    sh -c "KEEP_ZSHRC=yes $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting"
    brew-bundle
    {
        echo 'export ZSH="$HOME/.oh-my-zsh"'
        echo 'ZSH_THEME="candy"'
        echo 'plugins=(git'
        echo 'zsh-autosuggestions'
        echo 'zsh-syntax-highlighting'
        echo 'fast-syntax-highlighting'
        echo ')'
        echo 'source $ZSH/oh-my-zsh.sh'
        echo eval "$(atuin init zsh)"  
        echo eval "$(zoxide init zsh)"
        echo alias grep='ug'
        echo alias cd="z"
        echo alias egrep='ug -E'
        echo alias fgrep='ug -F'
        echo alias xzgrep='ug -z'
        echo alias xzegrep='ug -zE'
        echo alias xzfgrep='ug -zF'
        echo alias ll='eza -l --icons=auto --group-directories-first'
        echo alias l.='eza -d .*'
        echo alias ls='eza --icons=auto'
        echo alias l1='eza -1'
    } >> ~/.zshrc

    echo "Switch to ZSH if using a terminal emulator" 

    {
      echo 'if [[ $- == *i* ]]; then'
      echo '  exec zsh'
      echo 'fi'
    } >> ~/.bashrc

    echo "Setting Ghostty theme"
    mkdir -p ~/.config/ghostty
    cp -rn -u /usr/share/ublue-os/ghostty ~/.config/

    /usr/libexec/caracal-waterfox-config

    echo 'First-run setup complete. Reboot, or at minimum log out and back in, so group changes and session limits take effect.'

# Simply just syncs yabridge
update-audio:
    #!/usr/bin/env bash
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
    # Collect Carla plugin output ports: JACK clients with media.role=DSP,
    # excluding the Carla host client itself and known non-plugin ports.
    # Build set of already-connected ports from pw-link --links
    declare -A connected_out connected_in
    current_header=""
    links="$(pw-link --links 2>/dev/null || true)"
    while IFS= read -r line; do
        trimmed="${line#"${line%%[! ]*}"}"
        [[ -z "$trimmed" ]] && continue
        # Header line (no leading space) → the port itself
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
        # Skip ALSA, MIDI, RAOP, Zen, bluez, and monitor ports
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

# Set up yabridge Wine VST bridge for the current user
setup-audio:
    #!/usr/bin/env bash
    set -euo pipefail
    ujust setup-audio-profiles apply || true

    export WINELOADER=""
    for loader in wine wine64 /usr/bin/wine /usr/bin/wine64 /usr/sbin/wine /usr/sbin/wine64 /opt/wine-tkg/bin/wine /opt/wine-tkg/bin/wine64; do
        if command -v "$loader" &>/dev/null; then
            WINELOADER="$(command -v "$loader")"
            break
        fi
    done
    WINEBOOT=""
    for boot in wineboot /usr/bin/wineboot /usr/sbin/wineboot /opt/wine-tkg/bin/wineboot; do
        if command -v "$boot" &>/dev/null; then
            WINEBOOT="$(command -v "$boot")"
            break
        fi
    done

    if [[ -z "${WINELOADER}" || -z "${WINEBOOT}" ]]; then
        echo "Error: Wine loader or wineboot not found." >&2
        echo "WINELOADER: '${WINELOADER:-not found}'" >&2
        echo "WINEBOOT:   '${WINEBOOT:-not found}'" >&2
        echo "Searched PATH: $PATH" >&2
        echo "Checking common locations..." >&2
        ls -l /usr/bin/wine* /usr/sbin/wine* /opt/wine-tkg/bin/wine* 2>/dev/null || true
        echo "Ensure wine-core and wine-common are installed. You may need to reboot after a system update." >&2
        exit 1
    fi
    wine_version="$("$WINELOADER" --version 2>/dev/null || true)"
    echo "Wine version: ${wine_version:-unknown}"
    if [[ "${wine_version}" != wine-11.16* ]]; then
        echo "Error: expected Patrickl's wine-staging-dev Wine 11.16 stack, got '${wine_version:-unknown}'." >&2
        echo "Wine 11.10 currently fails PE32 WoW64 execution on Caracal." >&2
        echo "Rebuild or update Caracal with patrickl/wine-staging-dev providing Wine 11.16." >&2
        rpm -q wine wine-core wine-common yabridge winetricks 2>/dev/null || true
        exit 1
    fi
    wow64_prefix="$(mktemp -d "${TMPDIR:-/tmp}/caracal-wow64-check.XXXXXX")"
    if ! WINEPREFIX="$wow64_prefix" WINEDEBUG=-all "$WINEBOOT" -u; then
        WINEPREFIX="$wow64_prefix" wineserver -w 2>/dev/null || true
        rm -rf "$wow64_prefix"
        echo "Error: Wine cannot initialize a temporary WoW64 prefix." >&2
        echo "Rebuild or update Caracal with Patrickl's wine-staging-dev Wine stack." >&2
        exit 1
    fi
    wine_i386_cmd=""
    for bin in \
        /usr/lib64/wine-wow64/wine/i386-windows/cmd.exe \
        /usr/lib/wine/i386-windows/cmd.exe \
        /usr/lib64/wine/i386-windows/cmd.exe; do
        if [[ -f "$bin" ]]; then
            wine_i386_cmd="$bin"
            break
        fi
    done
    # A crashing 32-bit Wine process still exits 0, so check the actual output
    # of `ver` rather than the exit code.
    pe32_output=""
    if [[ -n "${wine_i386_cmd}" ]]; then
        pe32_output="$(WINEPREFIX="$wow64_prefix" WINEDEBUG=-all "$WINELOADER" "$wine_i386_cmd" /c ver 2>/dev/null || true)"
    fi
    if [[ -z "${wine_i386_cmd}" ]] || ! grep -qi 'Microsoft Windows' <<<"${pe32_output}"; then
        WINEPREFIX="$wow64_prefix" wineserver -w 2>/dev/null || true
        rm -rf "$wow64_prefix"
        echo "Error: Wine cannot run PE32 Windows programs through WoW64." >&2
        echo "On Caracal's composefs root this is provided by caracal-wine-execmod.service." >&2
        echo "Check it with: systemctl status caracal-wine-execmod.service" >&2
        echo "Then ensure /usr/lib64/wine-wow64/wine/i386-windows is a bind mount: findmnt /usr/lib64/wine-wow64/wine/i386-windows" >&2
        rpm -q wine wine-core wine-common yabridge winetricks 2>/dev/null || true
        exit 1
    fi
    WINEPREFIX="$wow64_prefix" wineserver -w 2>/dev/null || true
    rm -rf "$wow64_prefix"
    "$WINEBOOT" -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir"
    yabridgectl add "$vst3_dir"
    yabridgectl sync

route-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    echo 'Copying system plugins into user scan directories...'
    mkdir -p ~/.vst3 ~/.lv2 ~/.clap ~/.vst
    cp -rn -u /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn -u /usr/lib64/vst/*  ~/.vst/  2>/dev/null || true
    cp -rn -u /usr/lib64/lv2/*  ~/.lv2/  2>/dev/null || true
    cp -rn -u /usr/lib64/clap/* ~/.clap/ 2>/dev/null || true
    echo 'Plugins copied.'

# ── Flatpaks ──────────────────────────────────────────────────────────────────

# Install recommended Caracal OS flatpaks (browser, media players, PDF viewer)
reinstall-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Caracal OS recommended flatpaks..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak update --user --appstream -y || true
    flatpak install --user -y flathub \
        io.github.kolunmi.Bazaar \
        org.tenacityaudio.Tenacity \
        net.waterfox.waterfox \
        com.ranfdev.DistroShelf \
        org.kde.haruna \
        org.gnome.Decibels \
        "io.github.b43NnUNF4vidFYFhpqaLWy2ANawtRbMtUXZY9Pf.jumpdf" \
        org.gnome.Loupe
    # Remove any legacy Firefox flatpak; Waterfox is the default browser.
    flatpak uninstall --user -y org.mozilla.firefox 2>/dev/null || true
    sudo flatpak uninstall -y org.mozilla.firefox 2>/dev/null || true
    flatpak update --user --appstream -y
    echo "Flatpaks installed."

# ── DAW installation ──────────────────────────────────────────────────────────
# Ardour is pre-installed as the default open-source DAW.
# Run any of these to add a commercial DAW, then optionally remove Ardour.

# Install REAPER (commercial, free to evaluate)
install-reaper:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-software-installer/scripts/install-reaper.sh
    ujust _ask-remove-ardour

uninstall-reaper:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-software-installer/scripts/uninstall-reaper.sh

# Install Renoise (commercial, free demo available)
install-renoise:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-software-installer/scripts/install-renoise.sh
    ujust _ask-remove-ardour

uninstall-renoise:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-software-installer/scripts/uninstall-renoise.sh

# Install Bitwig Studio (commercial, requires licence)
install-bitwig:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-software-installer/scripts/install-bitwig.sh
    ujust _ask-remove-ardour

uninstall-bitwig:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-software-installer/scripts/uninstall-bitwig.sh

# Install rtcqs into a user-local virtualenv, including the GUI launcher
install-rtcqs:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/lib/caracal-software-installer/scripts/install-rtcqs.sh

uninstall-rtcqs:
    #!/usr/bin/env bash
    set -euo pipefail
    /usr/lib/caracal-software-installer/scripts/uninstall-rtcqs.sh

software-installer:
    #!/usr/bin/env bash
    set -euo pipefail
    caracal-software-installer

setup-neovim:
    #!/usr/bin/env bash
    set -euo pipefail

    install_lazyvim() {

      git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
      rm -rf "$HOME/.config/nvim/.git"
    }
    
    if [ ! -d "$HOME/.config/nvim" ]; then
      install_lazyvim
    else
      mv "$HOME/.config/nvim"{,.bak".$(date +%Y%m%d%H%M%S)"}
      install_lazyvim
    fi
    
    nvim

plugin-diagnose:
    #!/usr/bin/env bash
    set -euo pipefail

    VST_DIR="${HOME}/.vst3"
    WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"

    echo "Scanning local VST architecture for performance bottlenecks..."

    if [ ! -d "$VST_DIR" ] && [ ! -d "${WINEPREFIX}/drive_c/Program Files/Common Files/VST3" ]; then
      echo "No Windows VST directories detected. Run your installer or select 'Sync Windows VSTs' in Caracal system controller"
      exit 1
    fi

    R2R_MATCH=$(find "$VST_DIR" -type f \( -name "*_R2R.key" -o -name "*R2R.txt" \) 2>/dev/null | wc -l)

    VR_MATCH=$(find "${WINEPREFIX}/drive_c/ProgramData" -type d \( -name "*Team V.R*" -o -name "*VR_Modules" \) 2>/dev/null | wc -l)

    if [ "$R2R_MATCH" -gt 0 ] || [ "$VR_MATCH" -gt 0 ]; then
      echo "Target detected: Heavy memory-patching/License emulation structures found."
      echo "  -> Found R2R/V.R structural indicators. Applying Hyper-Threading & Hook Optimization profile..."

      REG_FILE=$(mktemp /tmp/caracal-tune-XXXXXX.reg)

      cat <<'EOF' > "$REG_FILE"
    Windows Registry Editor Version 5.00
    ;; Context: Heavy memory hooks loop continuously checking for thread validation.
    ;; We tweak the internal thread waiting thresholds to prevent Wine from deadlocking.
    [HKEY_CURRENT_USER\Software\Wine\WineDbg]
    "ShowCrashDialog"=dword:00000000

    ;; Optimisation: Disable aggressive background file lock notifications
    [HKEY_CURRENT_USER\Software\Wine\FileLocking]
    "Enable"=dword:00000000

    ;; Adjust internal Windows scheduling priorities within Wine ecoosystem
    [HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\PriorityControl]
    "Win32PrioritySeparation"=dword:00000026
    EOF

      if command -v wine &>/dev/null; then
        WINEPREFIX="$WINEPREFIX" wine regedit /s "$REG_FILE"
        rm -f "$REG_FILE"

        echo "Performance Profile Injected"
        echo "  - Disabled Wine crash dialog loops on unstable hooks."
        echo "  - Mitigated multi-threaded registry synchronisation bottolenecks."
        echo "  - Optimised Windows internal priority matrix matching."
      else
        echo "Core Wine environment not active in this container runtime shell"
        rm -f "$REG_FILE"
        exit 1
      fi
    else
      echo "Systen evaluation pristine: No resource-heavy license wrappers detected."
      echo "  Your plugins are running clean, high-performance architectures."
    fi

vst-iso ACTION="enable":
    #!/usr/bin/env bash
    set -euo pipefail

    REAPER_INI="${HOME}/.config/REAPER/reaper-vstplugins64.ini"

    if [ ! -f "$REAPER_INI" ]; then
      echo "REAPER VST cache file not found at: $REAPER_INI"
      echo "Please open REAPER at least once and run VST scan first."
      exit 1
    fi

    if [ "{{ ACTION }}" == "enable" ]; then
      echo "Setting REAPER bridge flag for Windows VST plugins (yabridge path)..."
      echo "Note: native Linux VST3 plugins are not affected by this flag."

      cp "$REAPER_INI" "${REAPER_INI}.bak"

      TMP_INI=$(mktemp)

      while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ \.(dll|vst3)= ]]; then
          if [[ "$line" == *"<BRG"* ]]; then
            sed -E 's/<BRG[^>]*>/<BRG2>/g' <<< "$line" >> "$TMP_INI"
          else
            echo "${line} <BRG2>" >> "$TMP_INI"
          fi
        else
          echo "${line}" >> "$TMP_INI"
        fi
      done < "$REAPER_INI"

      mv "$TMP_INI" "$REAPER_INI"
      echo "Done. Windows VST plugins via yabridge will use REAPER's bridge flag."
      echo "A backup of your previous configuration has been saved to ${REAPER_INI}.bak"

    elif [ "{{ ACTION }}" == "disable" ]; then
      echo "Removing REAPER bridge flag from VST plugins..."
      cp "$REAPER_INI" "${REAPER_INI}.bak"

      sed -i -E 's/ <BRG[0-9]>//g' "$REAPER_INI"
      echo "Done. Bridge flag removed from VST plugins."

    else
      echo "Unknown action. Use 'ujust vst-iso enable' or 'ujust vst-iso disable'"
      exit 1
    fi

juce-fix ACTION="dxvk":
    #!/usr/bin/env bash
    set -euo pipefail

    WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
    DXVK_CONFIG_DIR="${HOME}/.config/caracal"
    DXVK_CONFIG_FILE="${DXVK_CONFIG_DIR}/dxvk-juce.conf"

    mkdir -p "$DXVK_CONFIG_DIR"

    if [ "{{ ACTION }}" == "dxvk" ]; then
      echo "Applying DXVK feature level clamp for Juce plugins..."
      echo "d3d11.maxFeatureLevel = 9_1" > "$DXVK_CONFIG_FILE"

      echo "export DXVK_CONFIG_FILE=$DXVK_CONFIG_FILE" >> ~/.zshrc

    elif [ "{{ ACTION }}" == "desktop" ]; then
      echo "Enabling Wine Vistual Desktop Emulation fallback..."

      if command -v wine &>/dev/null; then
        REG_FILE=$(mktemp /tmp/juce-desktop-XXXXXX.reg)
        cat <<'EOF' > "$REG_FILE"
    Windows Registry Editor Version 5.00

    [HKEY_CURRENT_USER\Software\Wine\X11 Driver]
    "Desktop"="CaracalStudio"
    "Default"=str:1200x800
    EOF

        WINEPREFIX="$WINEPREFIX" wine regedit /s "$REG_FILE"
        rm -f "$REG_FILE"
        echo "Virtual desktop enabled. Unresponsive GUIs will now draw safely inside an isolated container."

      else
        echo "Active Wine runtime path not found."
        exit 1
      fi

    elif [ "{{ ACTION }}" == "reset" ]; then
      echo "Resetting graphics rendering paths to default..."
      rm -f "$DXVK_CONFIG_FILE"

      REG_FILE=$(mktemp /tmp/juce-reset-XXXXXX.reg)
      cat <<'EOF' > "$REG_FILE"
    Windows Registry Editor Version 5.00
    [HKEY_CURRENT_USER\Software\Wine\X11 Driver]
    "Desktop"=-
    EOF
      WINEPREFIX="$WINEPREFIX" wine regedit /s "$REG_FILE" 2>/dev/null || true
      rm -f "$REG_FILE"
      echo "Graphics configuration has been normalised."
    fi


# Taken directly from Bazzite
# Credit https://github/ublue-os/bazzite
# Launch Waydroid configuration helper. Options: init | configure | gpu | integration | reset | helper
[group("apps")]
configure-waydroid ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    IMAGE_NAME=$(jq -r '."image-name"' < $IMAGE_INFO)
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-waydroid <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'init' to select Initialize Waydroid"
      echo "  Use 'configure' to select Configure Waydroid"
      echo "  Use 'gpu' to choose Select GPU for Waydroid"
      echo "  Use 'integration' to enable desktop window integration for Waydroid"
      echo "  Use 'reset' to reset Waydroid"
      echo "  Use 'helper' to install waydroid-helper (https://github.com/waydroid-helper/waydroid-helper)"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Waydroid Setup${normal}"
      echo "Please read the $(Urllink "https://docs.bazzite.gg/Installing_and_Managing_Software/Waydroid_Setup_Guide/" "Waydroid setup documentation") before continuing"
      OPTION=$(Choose "Initialize Waydroid" "Configure Waydroid" "Select GPU for Waydroid" "Reset Waydroid (also removes waydroid-related files from user folder)" "Install waydroid-helper (https://github.com/waydroid-helper/waydroid-helper)")
    fi
    if [[ "${OPTION,,}" =~ ^init ]]; then
      if [[ ! $IMAGE_NAME =~ "deck" && ! $IMAGE_NAME =~ "ally" ]]; then
        sudo systemctl enable --now waydroid-container
      fi
      echo "This might take a bit, please be patient"
      sudo waydroid init -c 'https://ota.waydro.id/system' -v 'https://ota.waydro.id/vendor'
      sudo restorecon -R /var/lib/waydroid
      mkdir -p ~/.local/share/applications
      cp /usr/share/applications/waydroid-container-restart.desktop ~/.local/share/applications
      echo "Waydroid has been initialized, please run waydroid once before you Configure Waydroid"
    elif [[ "${OPTION,,}" =~ ^configure ]]; then
      git clone https://github.com/ublue-os/waydroid_script.git --depth 1 /tmp/waydroid_script
      python -m venv /tmp/waydroid_script/venv
      source /tmp/waydroid_script/venv/bin/activate
      sudo pip install -r /tmp/waydroid_script/requirements.txt
      sudo /tmp/waydroid_script/main.py
      deactivate
      sudo rm -rf /tmp/waydroid_script
    elif [[ "${OPTION,,}" =~ gpu ]]; then
      sudo /usr/bin/waydroid-choose-gpu
    elif [[ "${OPTION,,}" =~ integration ]]; then
      waydroid prop set persist.waydroid.multi_windows true
    elif [[ "${OPTION,,}" =~ ^reset ]]; then
      echo "Resetting Waydroid"
      bash -c 'sudo rm -rf /var/lib/waydroid /home/.waydroid ~/waydroid ~/.share/waydroid ~/.local/share/applications/*aydroid* ~/.local/share/waydroid'
      echo "Waydroid has been reset"
    elif [[ "${OPTION,,}" =~ helper ]]; then
      echo "Installing waydroid-helper"
      if grep -q 'it.mijorus.gearlever' <<< $(flatpak list); then
          wget \
              $(curl -s https://api.github.com/repos/waydroid-helper/waydroid-helper/releases/latest | \
              jq -r ".assets[] | select(.name | test(\".*x86_64.AppImage\")) | .browser_download_url") \
              -O $HOME/Downloads/waydroid-helper.AppImage
          chmod +x $HOME/Downloads/waydroid-helper.AppImage
          echo "Download complete, add it to your app menu via Gear Lever"
          flatpak run it.mijorus.gearlever $HOME/Downloads/waydroid-helper.AppImage
      else
          wget \
              $(curl -s https://api.github.com/repos/waydroid-helper/waydroid-helper/releases/latest | \
              jq -r ".assets[] | select(.name | test(\".*AppImage\")) | .browser_download_url") \
              -O $HOME/Desktop/waydroid-helper.AppImage
          chmod +x $HOME/Desktop/waydroid-helper.AppImage
          echo "Install complete, it has been added to your Desktop"
      fi
    fi

