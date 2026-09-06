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