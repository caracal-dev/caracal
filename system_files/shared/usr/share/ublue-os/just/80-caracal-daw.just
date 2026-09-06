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
    
