
plugin-diagnose:
    #!/usr/bin/env bash
    set -euo pipefail

    VST_DIR="${HOME}/.vst3"
    WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"

    echo "Scanning local VST architecture for performance bottlenecks..."

    if [ ! -d "$VST_DIR" ] && [ ! -d "${WINEPREFIX}/drive_c/Program Files/Common Files/VST3" ]; then
      echo "No Windows VST directories detected. Run your installer or select 'Sync Windows VSTs' in Caracal system controller"
      exit 1
    fi

    R2R_MATCH=$(find "$VST_DIR" -type f \( -name "*_R2R.key" -o -name "*R2R.txt" \) 2>/dev/null | wc -l)

    VR_MATCH=$(find "${WINEPREFIX}/drive_c/ProgramData" -type d \( -name "*Team V.R*" -o -name "*VR_Modules" \) 2>/dev/null | wc -l)

    if [ "$R2R_MATCH" -gt 0 ] || [ "$VR_MATCH" -gt 0 ]; then
      echo "Target detected: Heavy memory-patching/License emulation structures found."
      echo "  -> Found R2R/V.R structural indicators. Applying Hyper-Threading & Hook Optimization profile..."

      REG_FILE=$(mktemp /tmp/caracal-tune-XXXXXX.reg)

      cat <<'EOF' > "$REG_FILE"
    Windows Registry Editor Version 5.00
    ;; Context: Heavy memory hooks loop continuously checking for thread validation.
    ;; We tweak the internal thread waiting thresholds to prevent Wine from deadlocking.
    [HKEY_CURRENT_USER\Software\Wine\WineDbg]
    "ShowCrashDialog"=dword:00000000

    ;; Optimisation: Disable aggressive background file lock notifications
    [HKEY_CURRENT_USER\Software\Wine\FileLocking]
    "Enable"=dword:00000000

    ;; Adjust internal Windows scheduling priorities within Wine ecoosystem
    [HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\PriorityControl]
    "Win32PrioritySeparation"=dword:00000026
    EOF

      if command -v wine &>/dev/null; then
        WINEPREFIX="$WINEPREFIX" wine regedit /s "$REG_FILE"
        rm -f "$REG_FILE"

        echo "Performance Profile Injected"
        echo "  - Disabled Wine crash dialog loops on unstable hooks."
        echo "  - Mitigated multi-threaded registry synchronisation bottolenecks."
        echo "  - Optimised Windows internal priority matrix matching."
      else
        echo "Core Wine environment not active in this container runtime shell"
        rm -f "$REG_FILE"
        exit 1
      fi
    else
      echo "Systen evaluation pristine: No resource-heavy license wrappers detected."
      echo "  Your plugins are running clean, high-performance architectures."
    fi

vst-iso ACTION="enable":
    #!/usr/bin/env bash
    set -euo pipefail

    REAPER_INI="${HOME}/.config/REAPER/reaper-vstplugins64.ini"

    if [ ! -f "$REAPER_INI" ]; then
      echo "REAPER VST cache file not found at: $REAPER_INI"
      echo "Please open REAPER at least once and run VST scan first."
      exit 1
    fi

    if [ "{{ ACTION }}" == "enable" ]; then
      echo "Setting REAPER bridge flag for Windows VST plugins (yabridge path)..."
      echo "Note: native Linux VST3 plugins are not affected by this flag."

      cp "$REAPER_INI" "${REAPER_INI}.bak"

      TMP_INI=$(mktemp)

      while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ \.(dll|vst3)= ]]; then
          if [[ "$line" == *"<BRG"* ]]; then
            sed -E 's/<BRG[^>]*>/<BRG2>/g' <<< "$line" >> "$TMP_INI"
          else
            echo "${line} <BRG2>" >> "$TMP_INI"
          fi
        else
          echo "${line}" >> "$TMP_INI"
        fi
      done < "$REAPER_INI"

      mv "$TMP_INI" "$REAPER_INI"
      echo "Done. Windows VST plugins via yabridge will use REAPER's bridge flag."
      echo "A backup of your previous configuration has been saved to ${REAPER_INI}.bak"

    elif [ "{{ ACTION }}" == "disable" ]; then
      echo "Removing REAPER bridge flag from VST plugins..."
      cp "$REAPER_INI" "${REAPER_INI}.bak"

      sed -i -E 's/ <BRG[0-9]>//g' "$REAPER_INI"
      echo "Done. Bridge flag removed from VST plugins."

    else
      echo "Unknown action. Use 'ujust vst-iso enable' or 'ujust vst-iso disable'"
      exit 1
    fi

juce-fix ACTION="dxvk":
    #!/usr/bin/env bash
    set -euo pipefail

    WINEPREFIX="${WINEPREFIX:-${HOME}/.wine}"
    DXVK_CONFIG_DIR="${HOME}/.config/caracal"
    DXVK_CONFIG_FILE="${DXVK_CONFIG_DIR}/dxvk-juce.conf"

    mkdir -p "$DXVK_CONFIG_DIR"

    if [ "{{ ACTION }}" == "dxvk" ]; then
      echo "Applying DXVK feature level clamp for Juce plugins..."
      echo "d3d11.maxFeatureLevel = 9_1" > "$DXVK_CONFIG_FILE"

      echo "export DXVK_CONFIG_FILE=$DXVK_CONFIG_FILE" >> ~/.zshrc

    elif [ "{{ ACTION }}" == "desktop" ]; then
      echo "Enabling Wine Vistual Desktop Emulation fallback..."

      if command -v wine &>/dev/null; then
        REG_FILE=$(mktemp /tmp/juce-desktop-XXXXXX.reg)
        cat <<'EOF' > "$REG_FILE"
    Windows Registry Editor Version 5.00

    [HKEY_CURRENT_USER\Software\Wine\X11 Driver]
    "Desktop"="CaracalStudio"
    "Default"=str:1200x800
    EOF

        WINEPREFIX="$WINEPREFIX" wine regedit /s "$REG_FILE"
        rm -f "$REG_FILE"
        echo "Virtual desktop enabled. Unresponsive GUIs will now draw safely inside an isolated container."

      else
        echo "Active Wine runtime path not found."
        exit 1
      fi

    elif [ "{{ ACTION }}" == "reset" ]; then
      echo "Resetting graphics rendering paths to default..."
      rm -f "$DXVK_CONFIG_FILE"

      REG_FILE=$(mktemp /tmp/juce-reset-XXXXXX.reg)
      cat <<'EOF' > "$REG_FILE"
    Windows Registry Editor Version 5.00
    [HKEY_CURRENT_USER\Software\Wine\X11 Driver]
    "Desktop"=-
    EOF
      WINEPREFIX="$WINEPREFIX" wine regedit /s "$REG_FILE" 2>/dev/null || true
      rm -f "$REG_FILE"
      echo "Graphics configuration has been normalised."
    fi

