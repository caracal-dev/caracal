<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/images/caracal-banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="assets/images/caracal-banner-light.png">
  <img src="assets/images/caracal-banner-light.png" alt="Caracal OS">
</picture>

A custom [bootc](https://github.com/bootc-dev/bootc) image built on Fedora Kinoite (KDE Plasma), tuned from the ground up for audio production. Caracal-OS delivers a fast, immutable Linux desktop with everything a producer or sound engineer needs — baked into the image, ready on first boot.

---

## What's Inside

### Performance

- **Bazzite kernel** — replaces the stock Fedora kernel with Bazzite's pre-built OCI kernel image
- **CPU governor** — defaults to `performance` mode
- **Realtime/memlock limits** — `@audio` and `@realtime` groups preconfigured with `rtprio 95` and unlimited memlock

### DAWs (included)

| DAW | Notes |
|-----|-------|
| Ardour 9 | Full-featured professional DAW |
| Qtractor | MIDI/audio sequencer |
| Carla | Plugin host / patchbay |

**Optional DAWs** (install after first boot via `ujust`):

```
ujust install-reaper
ujust install-renoise
ujust install-bitwig
```

### Plugins & Instruments

Plugins are installed system-wide in LV2, VST3, and CLAP formats where available.

**Included out of the box:**

- LSP Plugins, ZAM Plugins, Calf, Dragonfly Reverb, BYOD
- OB-Xf, Vaporizer2, Odin2, Dexed, AIDA-X, Neural Amp Modeler
- INTERSECT, Wavetable, jDrummer, Crypt2, LostAndFoundPiano
- Guitarix, SooperLooper, Rakarrack
- Bristol, Synthv1, Drumkv1
- Surge XT, Decent Sampler (installed system-wide at build time)
- Full x42 and SWH LV2 plugin sets

**Windows VST support:**

- Wine TKG + Yabridge — run Windows VST2/VST3 plugins natively inside Linux DAWs

### Audio Stack

- JACK (`jack-audio-connection-kit`, `qjackctl`, `ffado` for FireWire interfaces)
- PipeWire + ALSA bridge (`pipewire-alsa`, `pavucontrol`)
- MIDI: QSynth, FluidSynth, General MIDI soundfont, Timidity++, VMPK, QMidiArp, HarmonySeq

### Shell & Tooling

- Zsh + Oh My Zsh (pre-configured skel in `/etc/skel`)
- `oh-my-posh` prompt, `eza`, `zoxide`, `fzf`, `ripgrep`, `fd`
- Neovim, Alacritty, 7zip, rsync

---

## Installation

### Prerequisites

- A machine running any bootc-compatible image (Bazzite, Bluefin, Aurora, or plain Fedora Atomic)
- A GitHub account (to pull the published image from GHCR)

### Switch to Caracal-OS

```bash
sudo bootc switch ghcr.io/caracal-dev/caracal:latest
```

Reboot to apply. On first login, add yourself to the audio and realtime groups:

```bash
ujust first-run
```

Or manually:

```bash
sudo usermod -aG audio,realtime $USER
```

Then log out and back in for the group changes to take effect.

---

## Building Locally

Requires [just](https://just.systems/) and Podman.

```bash
# Build the container image
just build

# Build a bootable QCOW2 (for testing in a VM)
just build-qcow2

# Run in a VM
just run-vm-qcow2
```

See the [Justfile](./Justfile) for all available recipes.

---

## Image Verification

All published images are signed with [cosign](https://github.com/sigstore/cosign). Verify with:

```bash
cosign verify --key cosign.pub ghcr.io/caracal-dev/caracal:latest
```

---

## Based On

- [Fedora Kinoite](https://fedoraproject.org/kinoite/) — KDE Plasma on Fedora Atomic
- [Universal Blue image-template](https://github.com/ublue-os/image-template)
- [Bazzite kernel](https://github.com/bazzite-org/kernel-bazzite)

## Special Thanks to:
- Fedora Kinoite - The base this image is built on
- Universal Blue - for making this type of project possible
- Bazzite - for the many performance enhancements
- [Secureblue](https://github.com/secureblue/secureblue) - for some security improvement ideas
- [Zirconium](https://github.com/zirconium-dev/zirconium) - excellent learning source
- [Zena](https://github.com/zena-linux/zena) for providing an example of CachyOS kernel implementation
