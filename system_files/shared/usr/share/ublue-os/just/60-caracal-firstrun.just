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
    source /usr/share/caracal/version-pins
    wine_version="$("$WINELOADER" --version 2>/dev/null || true)"
    echo "Wine version: ${wine_version:-unknown}"
    if [[ "${wine_version}" != wine-${WINE_VERSION}* ]]; then
        echo "Error: expected Patrickl's wine-staging-dev Wine ${WINE_VERSION} stack, got '${wine_version:-unknown}'." >&2
        echo "Wine 11.10 currently fails PE32 WoW64 execution on Caracal." >&2
        echo "Rebuild or update Caracal with patrickl/wine-staging-dev providing Wine ${WINE_VERSION}." >&2
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
    source /usr/share/caracal/version-pins
    wine_version="$("$WINELOADER" --version 2>/dev/null || true)"
    echo "Wine version: ${wine_version:-unknown}"
    if [[ "${wine_version}" != wine-${WINE_VERSION}* ]]; then
        echo "Error: expected Patrickl's wine-staging-dev Wine ${WINE_VERSION} stack, got '${wine_version:-unknown}'." >&2
        echo "Wine 11.10 currently fails PE32 WoW64 execution on Caracal." >&2
        echo "Rebuild or update Caracal with patrickl/wine-staging-dev providing Wine ${WINE_VERSION}." >&2
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