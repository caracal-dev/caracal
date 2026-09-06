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