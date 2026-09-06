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
# Credit https://github.com/ublue-os/bazzite
# Enable enhanced CLI tools (eza, atuin, zoxide, ugrep) in your shell