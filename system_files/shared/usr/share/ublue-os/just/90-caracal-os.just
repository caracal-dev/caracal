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

# ── Audio ─────────────────────────────────────────────────────────────────────

# Restart PipeWire (useful after config changes or audio glitches)
[group("audio")]
restart-pipewire:
    echo "Restarting PipeWire..."
    systemctl --user restart pipewire.service

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
    sudo usermod -aG audio,realtime "$target_user"


    # Set up Wine-native VST bridge
    export WINELOADER="$(command -v wine)"
    if [[ -z "${WINELOADER}" ]]; then
        echo "Wine is not installed or not on PATH." >&2
        exit 1
    fi
    wineboot -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir"
    yabridgectl add "$vst3_dir"
    yabridgectl sync

    echo "Added ${target_user} to audio and realtime."
    echo 'First-run setup complete. Reboot, or at minimum log out and back in, so group changes and session limits take effect.'
    echo 'Run  ujust install-flatpaks  to install recommended apps.'
    echo 'Run  ujust software-installer  for optional DAWs, plugins, and utilities.'

# Set up yabridge Wine VST bridge for the current user
setup-audio:
    #!/usr/bin/env bash
    set -euo pipefail
    export WINELOADER="$(command -v wine)"
    if [[ -z "${WINELOADER}" ]]; then
        echo "Wine is not installed or not on PATH." >&2
        exit 1
    fi
    wineboot -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir"
    yabridgectl add "$vst3_dir"
    yabridgectl sync

# Install Oh-My-Zsh and plugins
setup-zsh:
    #!/usr/bin/env bash
    set -euo pipefail
    sh -c "KEEP_ZSHRC=yes CHSH=yes $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting"
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete"

    {
        echo 'export ZSH="$HOME/.oh-my-zsh"'
        echo 'ZSH_THEME="robbyrussell"'
        echo 'plugins=(git'
        echo 'zsh-autosuggestions'
        echo 'zsh-syntax-highlighting'
        echo 'fast-syntax-highlighting'
        echo 'zsh-autocomplete'
        echo ')'
        echo 'source $ZSH/oh-my-zsh.sh'
    } >> ~/.zshrc

# Legacy helper: expose system plugins in Reaper's default user scan directories
route-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    echo 'Copying system plugins into Reaper user scan directories...'
    mkdir -p ~/.config/REAPER
    # Copy into Reaper's default user scan paths without editing REAPER config files.
    mkdir -p ~/.vst3 ~/.lv2 ~/.clap ~/.vst
    cp -rn /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn /usr/lib64/vst/*  ~/.vst/  2>/dev/null || true
    cp -rn /usr/lib64/lv2/*  ~/.lv2/  2>/dev/null || true
    cp -rn /usr/lib64/clap/* ~/.clap/ 2>/dev/null || true
    echo 'Plugins copied. Restart Reaper and rescan plugins if you choose to use this compatibility fallback.'

# ── Flatpaks ──────────────────────────────────────────────────────────────────

# Install recommended Caracal OS flatpaks (browser, media players, PDF viewer)
install-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Caracal OS recommended flatpaks..."
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub \
        io.github.kolunmi.Bazaar \
        org.tenacityaudio.Tenacity \
        app.zen_browser.zen \
        com.ranfdev.DistroShelf \
        org.kde.haruna \
        org.gnome.Decibels \
        "io.github.b43NnUNF4vidFYFhpqaLWy2ANawtRbMtUXZY9Pf.jumpdf" \
        org.gnome.Loupe
    # Remove any legacy Firefox flatpak; Zen Browser is the default browser.
    flatpak uninstall --user -y org.mozilla.firefox 2>/dev/null || true
    sudo flatpak uninstall -y org.mozilla.firefox 2>/dev/null || true
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
