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
    touch ~/.config/REAPER/reaper.ini
    sed -i '/^vstpath=/ s/$/;\/usr\/lib64\/vst3;\/usr\/lib64\/vst/' ~/.config/REAPER/reaper.ini
    sed -i '/^lv2path=/ s/$/;\/usr\/lib64\/lv2/' ~/.config/REAPER/reaper.ini
    sed -i '/^clappath=/ s/$/;\/usr\/lib64\/clap/' ~/.config/REAPER/reaper.ini
    mkdir -p ~/.vst3 ~/.vst
    cp -rn /usr/lib64/vst3/* ~/.vst3/ 2>/dev/null || true
    cp -rn /usr/lib64/vst/* ~/.vst/ 2>/dev/null || true
    echo 'Paths updated. Restart Reaper and clear cache/rescan.'

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
