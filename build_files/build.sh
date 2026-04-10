#!/bin/bash
# Caracal OS build script
# Runs inside the container build to install packages, configure the system,
# and apply branding. All scripts are available at /ctx/, assets at /ctx/assets/.

set -ouex pipefail

SCRIPTS_DIR="/ctx/scripts"

# ── Repositories ──────────────────────────────────────────────────────────────

# Wine TKG (provides: wine, yabridge)
dnf5 -y copr enable patrickl/wine-tkg

# Audio plugins (provides: various LV2/VST plugins)
dnf5 -y copr enable timlau/audio

# eza (modern ls replacement)
dnf5 -y copr enable alternateved/eza

# Universal Blue packages (provides: krunner-bazaar)
dnf5 -y copr enable ublue-os/packages

# ── Realtime support ──────────────────────────────────────────────────────────
dnf5 -y install realtime-setup

systemctl enable realtime-setup.service
systemctl enable realtime-entsk.service

# ── Remove unwanted defaults ──────────────────────────────────────────────────
dnf5 -y remove \
    zram-generator-defaults \
    nano \
    vim-minimal || true

# Remove Fedora logos so no Fedora branding leaks through (GRUB, icon cache, etc.)
# Swap to generic-logos first (satisfies virtual 'system-logos' provides), then erase it.
# Branding.sh installs our own distributor logo afterwards.
dnf5 -y swap fedora-logos generic-logos
rpm --erase --nodeps --nodb generic-logos

# ── COPR audio packages ───────────────────────────────────────────────────────
dnf5 -y install \
    yabridge \
    wine.x86_64 \
    winetricks \
    libcurl-gnutls \
    INTERSECT \
    INTERSECT-clap \
    INTERSECT-lv2 \
    INTERSECT-vst3 \
    Loopino-clap \
    Loopino \
    Wavetable \
    Wavetable-vst3 \
    Wavetable-lv2 \
    Wavetable-clap \
    jdrummer \
    jdrummer-vst3 \
    jdrummer-lv2 \
    jdrummer-clap \
    Vaporizer2 \
    Vaporizer2-vst3 \
    Vaporizer2-lv2 \
    Vaporizer2-clap \
    dexed \
    dexed-clap \
    dexed-vst3 \
    odin2 \
    odin2-vst3 \
    odin2-lv2 \
    Crypt2 \
    Crypt2-vst3 \
    Crypt2-clap \
    Crypt2-lv2 \
    OB-Xf \
    OB-Xf-vst3 \
    OB-Xf-clap \
    OB-Xf-lv2 \
    LostAndFoundPiano \
    LostAndFoundPiano-vst3 \
    LostAndFoundPiano-clap \
    LostAndFoundPiano-lv2 \
    BYOD \
    BYOD-lv2 \
    BYOD-clap \
    BYOD-vst3 \
    neural-amp-modeler-lv2 \
    AIDA-X \
    AIDA-X-clap \
    AIDA-X-vst3 \
    AIDA-X-lv2 \
    dragonfly-reverb \
    dragonfly-reverb-clap \
    dragonfly-reverb-vst3 \
    dragonfly-reverb-lv2 \
    eza


# ── Bazaar store ──────────────────────────────────────────────────────────────
dnf5 -y install krunner-bazaar

# ── General tooling ───────────────────────────────────────────────────────────
dnf5 -y install \
    zsh \
    openssl \
    openssh \
    7zip \
    rsync \
    neovim \
    alacritty \
    ripgrep \
    fd-find \
    zoxide \
    fzf \
    oh-my-posh

# ── Open-source DAWs ──────────────────────────────────────────────────────────
dnf5 -y install \
    ardour9 \
    qtractor \
    carla

# ── Audio plugins (Fedora repos) ──────────────────────────────────────────────
dnf5 -y install \
    lsp-plugins-vst \
    lsp-plugins-clap \
    lsp-plugins-lv2 \
    zam-plugins \
    calf \
    guitarix \
    sooperlooper \
    musescore

# ── Virtual instruments ───────────────────────────────────────────────────────
dnf5 -y install \
    hydrogen \
    yoshimi

# ── JACK audio ────────────────────────────────────────────────────────────────
dnf5 -y install \
    jack-audio-connection-kit \
    jack-audio-connection-kit-dbus \
    qjackctl \
    ffado

# ── PulseAudio / PipeWire tools ───────────────────────────────────────────────
dnf5 -y install \
    pavucontrol \
    pipewire-alsa

# ── MIDI ──────────────────────────────────────────────────────────────────────
dnf5 -y install \
    qsynth \
    fluidsynth \
    fluid-soundfont-gm \
    timidity++ \
    qmidiarp \
    vmpk \
    harmonyseq

# ── Synthesizers ──────────────────────────────────────────────────────────────
dnf5 -y install \
    bristol \
    synthv1 \
    drumkv1

# ── Guitar effects ────────────────────────────────────────────────────────────
dnf5 -y install \
    rakarrack

# ── LV2 plugins (Fedora repos) ────────────────────────────────────────────────
dnf5 -y install \
    lv2-ll-plugins \
    lv2-swh-plugins \
    lv2-vocoder-plugins \
    lv2-zynadd-plugins \
    lv2dynparam \
    lv2-abGate \
    lv2-samplv1 \
    lv2-synthv1 \
    lv2-drumkv1 \
    lv2-newtonator \
    lv2-x42-plugins \
    lv2-sorcer \
    lv2-fabla \
    lv2-carla

# ── Packages required by native Linux DAWs and the ujust DAW installers ──────
# kernel-tools / libX*: needed by Renoise (and other native apps)
# dpkg + libbsd: needed by ujust install-bitwig (extracts the .deb at runtime)
dnf5 -y install \
    kernel-tools \
    libX11 \
    libXext \
    libXcursor \
    libXrandr \
    libXinerama \
    libXv \
    dpkg \
    libbsd

# ── System configuration ──────────────────────────────────────────────────────

# Add Homebrew (linuxbrew) to the sudo secure_path so brew-installed tools
# are accessible under sudo. Not done via sudoers.d so upstream changes
# to the base sudoers file are still picked up on image updates.
# Adapted from https://github.com/ublue-os/aurora (Aurora contributors)
sed -Ei "s/secure_path = (.*)/secure_path = \1:\/home\/linuxbrew\/.linuxbrew\/bin/" /etc/sudoers

# CPU governor: default to performance mode for low-latency audio
mkdir -p /etc/sysconfig
echo 'START_OPTS="--governor performance"' > /etc/sysconfig/cpupower

# Realtime/memlock permissions for audio production groups
mkdir -p /etc/security/limits.d
cat > /etc/security/limits.d/audio.conf << 'EOF'
@audio    -  rtprio     95
@audio    -  memlock    unlimited
@realtime -  rtprio     95
@realtime -  memlock    unlimited
EOF

# Ensure audio group exists (user must run `ujust first-run` or
# `usermod -aG audio $USER` to join it)
getent group audio || groupadd -r audio

# ── Services ──────────────────────────────────────────────────────────────────
systemctl enable cpupower.service
systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable usr-share-sddm-themes.mount

# User-level service: applies branding (wallpaper, lock screen) on first login
# and after any bootc rebase, ensuring branding is consistent regardless of
# whether the user installed fresh or switched from another image.
chmod +x /usr/libexec/caracal-user-setup
systemctl --global enable caracal-user-setup.service

# ── Plugins / instruments installed system-wide ───────────────────────────────
# Surge XT and Decent Sampler are installed for all users at build time.
# Reaper, Renoise, and Bitwig are optional — install via: ujust install-<daw>
bash "${SCRIPTS_DIR}/installsurgext.sh"
bash "${SCRIPTS_DIR}/installdecentsampler.sh"

# ── Branding ──────────────────────────────────────────────────────────────────
bash "${SCRIPTS_DIR}/branding.sh"

# ── Cleanup ───────────────────────────────────────────────────────────────────
# Remove package-manager state that bootc flags as unexpected /var content.
# dnf5 and dpkg leave repo metadata and state files here during the build;
# none of it should be in the final deployed image.
rm -rf \
    /var/lib/dnf \
    /var/lib/dpkg \
    /var/lib/alternatives \
    /var/log/dnf* \
    /var/log/hawkey*

# cachyos-settings and cachyos-ksm-settings install files into /usr/etc.
# bootc treats /usr/etc as an internal implementation detail — it must not
# exist in the image. Remove it so the lint and deployment both pass.
rm -rf /usr/etc
