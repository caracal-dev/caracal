# Caracal pro-audio ujust recipes for Universal Blue images (Bazzite / Aurora)
#
# Drop this file into a Universal Blue image at:
#   /usr/share/ublue-os/just/90-caracal-pro-audio.just
#
# Users then run:
#   ujust pro-audio              # interactive menu
#   ujust pro-audio-info         # print what this does, change nothing
#   ujust pro-audio-uninstall    # remove the layered Caracal pieces
#
# What this provides:
#   - Layers the Caracal Software Installer (curated DAW / plugin / instrument
#     catalog with desktop GUI, TUI, and CLI helpers) and the Caracal Audio
#     Controller service from the upstream COPR.
#   - Applies the realtime / memlock tuning Caracal ships out of the box
#     (limits.d for @audio and @realtime, systemd manager defaults).
#   - Creates the audio and realtime groups, adds the invoking user to both.
#   - Switches the CPU governor to performance for low-latency DAW work.
#   - Stages a focused set of audio packages (yabridge + Wine TKG for Windows
#     VSTs, JACK / PipeWire bridges, plugin scan paths, common firmware).
#
# Everything heavier — DAWs, large plugin packs, instrument libraries — is
# handled interactively from the Caracal Software Installer after first boot,
# so the base image footprint stays small.
#
# Caracal upstream: https://github.com/caracal-dev/caracal

# Interactive pro-audio setup (Caracal Software Installer + realtime tuning)
[group("audio")]
pro-audio ACTION="":
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh

    if [[ $(id -u) -eq 0 ]]; then
        echo "Please run 'ujust pro-audio' as your regular user, not root."
        exit 1
    fi

    OPTION="{{ ACTION }}"
    if [[ "$OPTION" == "help" ]]; then
        echo "Usage: ujust pro-audio <option>"
        echo "  full              Do everything below in one go (recommended)"
        echo "  installer         Layer only the Caracal Software Installer"
        echo "  audio-stack       Layer Caracal's curated audio package set"
        echo "  realtime-tuning   Apply realtime / memlock limits + groups"
        echo "  cpu-performance   Switch CPU governor to performance"
        echo "  yabridge-setup    Initialize Wine + yabridge for the current user"
        exit 0
    elif [[ -z "$OPTION" ]]; then
        echo "${bold}Caracal pro-audio setup${normal}"
        echo "Bring this system up to Caracal's pro-audio baseline."
        OPTION=$(Choose \
            "Full setup (recommended)" \
            "Install Caracal Software Installer only" \
            "Install Caracal audio stack only" \
            "Apply realtime tuning only" \
            "Apply CPU performance tuning only" \
            "Set up yabridge for current user" \
            "Cancel" \
        )
    fi

    case "${OPTION,,}" in
        full|"full setup (recommended)")
            ujust _pro-audio-copr
            ujust _pro-audio-audio-stack
            ujust _pro-audio-installer
            ujust _pro-audio-realtime
            ujust _pro-audio-cpu-performance
            ujust _pro-audio-summary
            ;;
        installer|"install caracal software installer only")
            ujust _pro-audio-copr
            ujust _pro-audio-installer
            ujust _pro-audio-summary
            ;;
        audio-stack|"install caracal audio stack only")
            ujust _pro-audio-copr
            ujust _pro-audio-audio-stack
            ujust _pro-audio-summary
            ;;
        realtime-tuning|"apply realtime tuning only")
            ujust _pro-audio-realtime
            ;;
        cpu-performance|"apply cpu performance tuning only")
            ujust _pro-audio-cpu-performance
            ;;
        yabridge-setup|"set up yabridge for current user")
            ujust _pro-audio-yabridge
            ;;
        cancel|"")
            echo "Cancelled."
            ;;
        *)
            echo "Unknown option: $OPTION"
            echo "Run 'ujust pro-audio help' for usage."
            exit 1
            ;;
    esac

# Print what 'ujust pro-audio' would do, change nothing
[group("audio")]
pro-audio-info:
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    cat <<EOF
    ${bold}ujust pro-audio${normal} brings this system up to Caracals pro-audio baseline.

    It will:
      * Enable the ${bold}tumillanino/caracal-packages${normal} COPR
        (publisher of caracal-software-installer / caracal-audio-controller).
      * Enable the ${bold}patrickl/wine-11.8-vstgui-juce8${normal}, ${bold}patrickl/wine-tkg-dev${normal}, and ${bold}teervo/DISTRHO${normal} COPRs
        for yabridge + Windows VST support and the DISTRHO plugin set.
      * Layer the Caracal Software Installer and Audio Controller, plus a
        focused audio package set (yabridge, JACK / PipeWire bridges,
        qjackctl, ffado, pavucontrol, helvum, easyeffects, lsp-plugins,
        calf, guitarix, lv2-carla, DISTRHO drumsynth / eqinox / vitalium,
        audio firmware, kernel-tools, dpkg + libbsd for the DAW installers).
      * Drop ${bold}/etc/security/limits.d/audio.conf${normal} granting
        rtprio 95 and unlimited memlock to @audio and @realtime.
      * Drop systemd manager defaults for DefaultLimitMEMLOCK / DefaultLimitRTPRIO.
      * Create the audio and realtime groups and add \$USER to both.
      * Switch the CPU governor to performance via cpupower.
      * Run wineboot + yabridgectl for the current user.

    Heavier installs (REAPER, Renoise, Bitwig, Mixbus, Zrythm, large plugin
    libraries, instrument packs) are not layered onto the image. Once first
    boot is done, launch the ${bold}Caracal Software Installer${normal} from the
    app launcher or run:

        ujust pro-audio caracal-software-installer

    to pick from the curated catalog. Plugin installs land in
    ~/.vst3 / ~/.clap / ~/.lv2 where possible so they survive image updates.

    Reboot is required after the layered packages and kernel-arg / limits
    changes for everything to take full effect.
    EOF

# Launch the Caracal Software Installer (TUI / CLI; GUI is in the app launcher)
[group("audio")]
caracal-software-installer:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v caracal-software-installer >/dev/null 2>&1; then
        echo "Caracal Software Installer is not installed yet."
        echo "Run 'ujust pro-audio' first."
        exit 1
    fi
    caracal-software-installer

# Remove the Caracal-specific layered packages and config
[group("audio")]
pro-audio-uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    echo "${bold}Remove Caracal pro-audio layering?${normal}"
    echo "This unlayers caracal-software-installer / caracal-audio-controller,"
    echo "removes the limits.d and systemd manager drop-ins, and disables the"
    echo "Caracal COPRs. Audio packages from Fedora repos (PipeWire, JACK,"
    echo "lsp-plugins, calf, etc.) are kept."
    CHOICE=$(Choose Cancel Continue)
    if [[ "$CHOICE" != "Continue" ]]; then
        exit 0
    fi

    sudo rpm-ostree uninstall \
        --idempotent \
        caracal-software-installer \
        caracal-audio-controller || true

    sudo rm -f \
        /etc/yum.repos.d/_copr_tumillanino-caracal-packages.repo \
        /etc/yum.repos.d/_copr_patrickl-wine-tkg.repo \
        /etc/yum.repos.d/_copr_patrickl-wine-11.8-vstgui-juce8.repo \
        /etc/yum.repos.d/_copr_patrickl-wine-tkg-dev.repo \
        /etc/yum.repos.d/_copr_teervo-DISTRHO.repo \
        /etc/security/limits.d/audio.conf \
        /etc/systemd/system.conf.d/90-caracal-audio.conf \
        /etc/systemd/user.conf.d/90-caracal-audio.conf

    echo "Removed. Reboot to finish unlayering."

# ── Private helpers ───────────────────────────────────────────────────────────

[private]
_pro-audio-copr:
    #!/usr/bin/env bash
    set -euo pipefail
    fedora_release="$(rpm -E %fedora)"
    add_copr() {
        local owner="$1" project="$2"
        local filename="_copr_${owner}-${project}.repo"
        local url="https://copr.fedorainfracloud.org/coprs/${owner}/${project}/repo/fedora-${fedora_release}/${owner}-${project}-fedora-${fedora_release}.repo"
        if [[ ! -f "/etc/yum.repos.d/${filename}" ]]; then
            echo "Enabling COPR ${owner}/${project}..."
            sudo curl -fsSL "${url}" -o "/etc/yum.repos.d/${filename}" || return 1
        else
            echo "COPR ${owner}/${project} already enabled."
        fi
    }
    set_copr_priority() {
        local owner="$1" project="$2" priority="$3"
        local repo_file="/etc/yum.repos.d/_copr_${owner}-${project}.repo"
        [[ -f "$repo_file" ]] || return 0

        if grep -q '^priority=' "$repo_file"; then
            sudo sed -i "s/^priority=.*/priority=${priority}/" "$repo_file"
        else
            printf 'priority=%s\n' "$priority" | sudo tee -a "$repo_file" >/dev/null
        fi
    }
    add_copr tumillanino caracal-packages
    if add_copr patrickl wine-11.8-vstgui-juce8; then
        set_copr_priority patrickl wine-11.8-vstgui-juce8 80
    else
        echo "WARNING: failed to enable patrickl/wine-11.8-vstgui-juce8; falling back to patrickl/wine-tkg-dev." >&2
    fi
    add_copr patrickl    wine-tkg-dev
    add_copr teervo      DISTRHO
    set_copr_priority patrickl wine-tkg-dev 90
    # rpmfusion-free is required for several multimedia codecs and ffmpeg.
    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        sudo rpm-ostree install --idempotent \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_release}.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_release}.noarch.rpm"
    fi

[private]
_pro-audio-installer:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Layering Caracal Software Installer + Audio Controller..."
    sudo rpm-ostree install --idempotent \
        caracal-software-installer \
        caracal-audio-controller

[private]
_pro-audio-audio-stack:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Layering Caracal pro-audio package set..."
    packages=(
        # Wine VST bridge stack
        yabridge
        wine.x86_64
        wine-core.x86_64
        winetricks
        wine-mono
        wine-dxvk
        libcurl-gnutls
        # JACK + PipeWire compatibility
        pipewire-jack-audio-connection-kit
        jack-audio-connection-kit-dbus
        qjackctl
        ffado
        pavucontrol
        pipewire-alsa
        pipewire-utils
        helvum
        easyeffects
        rtkit
        wireplumber
        # Codecs and gstreamer plugins for media playback inside DAWs
        lame
        flac
        libavcodec-freeworld
        gstreamer1-plugins-bad-freeworld
        gstreamer1-plugins-good
        gstreamer1-plugins-ugly
        gstreamer1-libav
        # ALSA + hardware diagnostics
        alsa-utils
        alsa-plugins-jack
        usbutils
        pciutils
        i2c-tools
        ddcutil
        evtest
        a2jmidid
        midisport-firmware
        # Audio firmware
        alsa-firmware
        alsa-sof-firmware
        alsa-tools-firmware
        intel-audio-firmware
        # Plugins shipped on Caracal
        lsp-plugins-vst
        lsp-plugins-clap
        lsp-plugins-lv2
        calf
        guitarix
        lv2-carla
        vst-DISTRHO-drumsynth.x86_64
        vst-DISTRHO-eqinox.x86_64
        vst-DISTRHO-vitalium.x86_64
        # Required by REAPER / Renoise / Bitwig installers shipped in the
        # Caracal Software Installer.
        kernel-tools
        libX11
        libXext
        libXcursor
        libXrandr
        libXinerama
        libXv
        dpkg
        libbsd
        # Realtime helpers
        realtime-setup
        tuned-profiles-realtime
    )
    sudo rpm-ostree install --idempotent "${packages[@]}"

[private]
_pro-audio-realtime:
    #!/usr/bin/env bash
    set -euo pipefail
    target_user="${SUDO_USER:-$(logname 2>/dev/null || id -un)}"
    if [[ -z "$target_user" ]] || [[ "$target_user" == "root" ]]; then
        echo "Could not determine the target user. Run 'ujust pro-audio' as your normal user."
        exit 1
    fi

    sudo getent group audio    >/dev/null || sudo groupadd -r audio
    sudo getent group realtime >/dev/null || sudo groupadd -r realtime
    sudo usermod -aG audio,realtime "$target_user"

    echo "Writing /etc/security/limits.d/audio.conf..."
    sudo install -d -m 0755 /etc/security/limits.d
    sudo tee /etc/security/limits.d/audio.conf >/dev/null <<'EOF'
    @audio    -  rtprio     95
    @audio    -  memlock    unlimited
    @realtime -  rtprio     95
    @realtime -  memlock    unlimited
    EOF

    echo "Writing systemd manager DefaultLimit* drop-ins..."
    sudo install -d -m 0755 /etc/systemd/system.conf.d /etc/systemd/user.conf.d
    sudo tee /etc/systemd/system.conf.d/90-caracal-audio.conf >/dev/null <<'EOF'
    [Manager]
    DefaultLimitMEMLOCK=infinity
    DefaultLimitRTPRIO=95
    EOF
    sudo tee /etc/systemd/user.conf.d/90-caracal-audio.conf >/dev/null <<'EOF'
    [Manager]
    DefaultLimitMEMLOCK=infinity
    DefaultLimitRTPRIO=95
    EOF

    if systemctl list-unit-files realtime-setup.service >/dev/null 2>&1; then
        sudo systemctl enable realtime-setup.service || true
    fi
    if systemctl list-unit-files realtime-entsk.service >/dev/null 2>&1; then
        sudo systemctl enable realtime-entsk.service || true
    fi

    echo "Realtime tuning applied. Log out and back in (or reboot) for"
    echo "group membership and session limits to take effect."

[private]
_pro-audio-cpu-performance:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v cpupower >/dev/null 2>&1; then
        echo "cpupower is not on PATH yet (kernel-tools may still be staged"
        echo "by rpm-ostree). It will work after the next reboot."
        sudo install -d -m 0755 /etc/sysconfig
        echo 'START_OPTS="--governor performance"' \
            | sudo tee /etc/sysconfig/cpupower >/dev/null
        sudo systemctl enable cpupower.service 2>/dev/null || true
        exit 0
    fi

    echo "Setting CPU governor to performance via cpupower..."
    sudo cpupower frequency-set -g performance >/dev/null
    sudo install -d -m 0755 /etc/sysconfig
    echo 'START_OPTS="--governor performance"' \
        | sudo tee /etc/sysconfig/cpupower >/dev/null
    sudo systemctl enable --now cpupower.service 2>/dev/null || true

    shopt -s nullglob
    governor_paths=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor)
    if ((${#governor_paths[@]})); then
        printf 'CPU governors now: '
        for path in "${governor_paths[@]}"; do
            [[ -r "$path" ]] && printf '%s\n' "$(<"$path")"
        done | sort -u | paste -sd ', ' -
    fi

[private]
_pro-audio-yabridge:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v wine >/dev/null 2>&1; then
        echo "Wine is not installed yet. Run 'ujust pro-audio audio-stack',"
        echo "reboot, then come back and run this step."
        exit 1
    fi
    if ! command -v yabridgectl >/dev/null 2>&1; then
        echo "yabridgectl is not installed yet. Run 'ujust pro-audio audio-stack',"
        echo "reboot, then come back and run this step."
        exit 1
    fi
    export WINELOADER="$(command -v wine)"
    wineboot -u
    vst3_dir="$HOME/.wine/drive_c/Program Files/Common Files/VST3"
    mkdir -p "$vst3_dir" "$HOME/.vst3" "$HOME/.clap" "$HOME/.lv2" "$HOME/.vst"
    yabridgectl add "$vst3_dir"
    yabridgectl sync
    echo "yabridge initialized. Drop Windows VSTs into:"
    echo "  $vst3_dir"
    echo "then run 'yabridgectl sync' (or this recipe) again."

[private]
_pro-audio-summary:
    #!/usr/bin/env bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    cat <<EOF

    ${bold}Caracal pro-audio setup queued.${normal}

    Next steps:
      1. ${bold}Reboot${normal} so the layered packages, group membership,
         and session limits all take effect:

             systemctl reboot

      2. After reboot, launch the ${bold}Caracal Software Installer${normal}
         from the app launcher, or run:

             ujust pro-audio caracal-software-installer

         to install DAWs (REAPER, Renoise, Bitwig, Mixbus, Zrythm, Stargate,
         Helio), instruments (VCV Rack, Surge XT, Decent Sampler, Vital,
         SunVox, Dexed, Odin2, OB-Xf, TAL, Yoshimi, ...), and effects
         (Dragonfly, Neural Amp Modeler, AIDA-X, ChowDSP, Zam, DPF, ...).

      3. If you want Windows VST plugin support, run:

             ujust pro-audio yabridge-setup

         once Wine is on PATH (i.e. after the reboot in step 1).

    More: https://github.com/caracal-dev/caracal
    EOF
