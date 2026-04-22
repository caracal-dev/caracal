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

# ── First-run & setup ─────────────────────────────────────────────────────────

# First-run setup: add audio/realtime groups, install shell extras, and set up yabridge
first-run:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo usermod -aG audio,realtime "$USER"

    # Install Oh-My-Zsh (--unattended skips exec zsh at the end so this script can continue)
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting"
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete"

    {
        echo 'plugins=(git'
        echo 'zsh-autosuggestions'
        echo 'zsh-syntax-highlighting'
        echo 'fast-syntax-highlighting'
        echo 'zsh-autocomplete'
        echo ')'
    } >> ~/.zshrc

    echo 'eval "$(oh-my-posh init zsh --config '"'"'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/json.omp.json'"'"')"' >> ~/.zshrc

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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting"
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete"
    {
        echo 'plugins=(git'
        echo 'zsh-autosuggestions'
        echo 'zsh-syntax-highlighting'
        echo 'fast-syntax-highlighting'
        echo 'zsh-autocomplete'
        echo ')'
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
