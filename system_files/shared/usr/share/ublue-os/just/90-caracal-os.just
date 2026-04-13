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
            cat <<-'EOF' >> "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
	### caracal bling source start
	test -f /usr/share/caracal-cli/bling.fish && source /usr/share/caracal-cli/bling.fish
	### caracal bling source end
EOF
        elif [[ "${shell}" == "zsh" ]]; then
            cat <<-'EOF' >> "${ZDOTDIR:-$HOME}/.zshrc"
	### caracal bling source start
	test -f /usr/share/caracal-cli/bling.sh && source /usr/share/caracal-cli/bling.sh
	### caracal bling source end
EOF
        elif [[ "${shell}" == "bash" ]]; then
            cat <<-'EOF' >> "${HOME}/.bashrc"
	### caracal bling source start
	test -f /usr/share/caracal-cli/bling.sh && source /usr/share/caracal-cli/bling.sh
	### caracal bling source end
EOF
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
        sudo tee "$CONFIG_FILE" > /dev/null <<'EOF'
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}

monitor.bluez.properties = {
  bluez5.roles = [ a2dp_sink a2dp_source ]
}
EOF
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
        cat > ~/.config/pipewire/pipewire.conf.d/virtual-channels.conf << 'EOF'
context.modules = [
    { name = libpipewire-module-loopback
        args = {
            node.description = "DAW"
            capture.props = {
                node.name      = "sink.daw"
                media.class    = "Audio/Sink"
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name    = "playback.daw"
                node.passive = true
                audio.position = [ FL FR ]
            }
        }
    }
    { name = libpipewire-module-loopback
        args = {
            node.description = "Monitoring"
            capture.props = {
                node.name      = "sink.monitoring"
                media.class    = "Audio/Sink"
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name    = "playback.monitoring"
                node.passive = true
                audio.position = [ FL FR ]
            }
        }
    }
    { name = libpipewire-module-loopback
        args = {
            node.description = "Recording"
            capture.props = {
                node.name      = "sink.recording"
                media.class    = "Audio/Sink"
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name    = "playback.recording"
                node.passive = true
                audio.position = [ FL FR ]
            }
        }
    }
    { name = libpipewire-module-loopback
        args = {
            node.description = "System"
            capture.props = {
                node.name      = "sink.system"
                media.class    = "Audio/Sink"
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name    = "playback.system"
                node.passive = true
                audio.position = [ FL FR ]
            }
        }
    }
]
EOF
        echo "Virtual channels created: DAW, Monitoring, Recording, System"
        echo "Log out and back in (or run ujust restart-pipewire) for them to appear."
        echo "Route them in qpwgraph, Helvum, or Carla."
    elif [[ "${OPTION,,}" =~ ^remove ]]; then
        rm -f ~/.config/pipewire/pipewire.conf.d/virtual-channels.conf
        echo "Virtual channels removed. Log out or run ujust restart-pipewire to apply."
    fi

# ── First-run & setup ─────────────────────────────────────────────────────────

# First-run setup: join audio group, install Oh-My-Zsh + plugins, configure Reaper paths
first-run:
    #!/usr/bin/env bash
    set -euo pipefail
    usermod -aG audio "$USER"

    # Install Oh-My-Zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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
    export WINELOADER='/opt/wine-staging/bin/wine'
    wineboot -u
    yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    yabridgectl sync

    echo 'First-run setup complete. Log out and back in for group changes to take effect.'
    echo 'Run  ujust install-flatpaks  to install recommended apps.'
    echo 'Run  ujust install-reaper / install-renoise / install-bitwig  for optional DAWs.'

# Set up yabridge Wine VST bridge for the current user
setup-audio:
    #!/usr/bin/env bash
    set -euo pipefail
    export WINELOADER='/opt/wine-staging/bin/wine'
    wineboot -u
    yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    yabridgectl sync

# Install Oh-My-Zsh and plugins
setup-zsh:
    #!/usr/bin/env bash
    set -euo pipefail
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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

# Add /usr/lib64 VST/LV2/CLAP directories to Reaper's plugin search paths
route-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    echo 'Configuring Reaper plugin paths...'
    mkdir -p ~/.config/REAPER
    # Copy system plugins to user directories (default scan paths — no ini required)
    mkdir -p ~/.vst3 ~/.lv2 ~/.clap ~/.vst
    cp -rn /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn /usr/lib64/vst/*  ~/.vst/  2>/dev/null || true
    cp -rn /usr/lib64/lv2/*  ~/.lv2/  2>/dev/null || true
    cp -rn /usr/lib64/clap/* ~/.clap/ 2>/dev/null || true
    echo 'Plugins copied. Restart Reaper and rescan plugins.'

# ── Flatpaks ──────────────────────────────────────────────────────────────────

# Install recommended Caracal OS flatpaks (browser, media players, PDF viewer)
install-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Installing Caracal OS recommended flatpaks..."
    sudo flatpak install -y flathub \
        org.tenacityaudio.Tenacity \
        app.zen_browser.zen \
        com.ranfdev.DistroShelf \
        org.kde.haruna \
        org.gnome.Decibels \
        "io.github.b43NnUNF4vidFYFhpqaLWy2ANawtRbMtUXZY9Pf.jumpdf" \
        org.gnome.Loupe
    # Remove Firefox (replaced by Zen Browser)
    flatpak uninstall --user -y org.mozilla.firefox 2>/dev/null || true
    echo "Flatpaks installed."

# ── DAW installation ──────────────────────────────────────────────────────────
# Ardour is pre-installed as the default open-source DAW.
# Run any of these to add a commercial DAW, then optionally remove Ardour.

# Install REAPER (commercial, free to evaluate)
install-reaper:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-os/scripts/install-reaper.sh
    just route-plugins
    just _ask-remove-ardour

# Install Renoise (commercial, free demo available)
install-renoise:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-os/scripts/install-renoise.sh
    just _ask-remove-ardour

# Install Bitwig Studio (commercial, requires licence)
install-bitwig:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo /usr/lib/caracal-os/scripts/install-bitwig.sh
    just _ask-remove-ardour
