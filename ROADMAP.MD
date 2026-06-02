# Caracal OS Roadmap

This document outlines the development path for Caracal OS. Our goal is to provide the most reliable, high-performance, and "ready-to-record" Linux distribution for audio production.

---

## 🏁 Phase 1: Foundation (Completed)
The core infrastructure and baseline performance tuning.

- [x] **Base Image:** Immutable Fedora Kinoite foundation with `bootc` support.
- [x] **Kernel Tuning:** Integration of the Bazzite kernel for superior scheduling and latency.
- [x] **Audio Optimization:** Preconfigured `realtime` and `audio` groups, memlock limits, and CPU governor defaults.
- [x] **Core DAW Suite:** Out-of-the-box inclusion of Ardour, Carla, and Qtractor.
- [x] **Windows VST Support:** Preconfigured Wine-TKG and Yabridge environment.
- [x] **Branding & Identity:** Custom splash screens, SDDM themes, and Plymouth integration.
- [x] **Automated Builds:** CI/CD pipeline for container images and bootable ISO/QCOW2 disks.

---

## 🚀 Phase 2: Refinement (Near-Term)
Improving the "first 15 minutes" and expanding the ecosystem.

- [ ] **Caracal Software Installer Catalog Expansion:** Adding more curated Linux-native plugins (CLAP, VST3, LV2) to the Software Installer.
- [ ] **Streamlined First-Run:** Enhancing `ujust first-run` with a graphical or interactive setup wizard for hardware selection.
- [ ] **Hardware Quirk Database:** Expanding `/usr/lib/modprobe.d/` with more specific quirks for professional USB and FireWire interfaces.
- [ ] **DAW Configuration Templates:** Pre-optimized project templates for included DAWs to minimize setup time.
- [ ] **Documentation Wiki:** Detailed guides on Yabridge management, Homebrew integration, and low-latency troubleshooting.
- [ ] **Flatpak Volume Normalization:** Finalizing system-wide PipeWire/WirePlumber rules for consistent audio levels across apps.

---

## 🌐 Phase 3: Ecosystem (Mid-Term)
Building tools for the community and developers.

- [ ] **Community Contribution Pipeline:** A formal process for users to submit new software metadata for the Caracal Installer.
- [ ] **Plugin Development SDK:** A specialized `distrobox` container pre-loaded with tools for building Linux plugins.
- [ ] **Automated Regression Testing:** CI-based audio engine tests to ensure kernel or package updates don't regale latency performance.
- [ ] **Backup & Restore Integration:** Built-in tools for backing up DAW settings and user-local plugin folders (`~/.vst3`, etc.).
- [ ] **Improved NVIDIA Integration:** Fine-tuning GPU-accelerated plugin rendering for NVIDIA hardware.

---

## 🏆 Phase 4: Professional Standard (Long-Term)
Establishing Caracal as a benchmark for Linux audio production.

- [ ] **Low-Latency Benchmarking Suite:** Continuous monitoring of system jitter and round-trip latency.
- [ ] **Professional Hardware Certification:** Collaborating with hardware vendors to ensure "out-of-the-box" support for high-end interfaces.
- [ ] **Collaborative Studio Features:** Native integration for version control (Git-based) in music projects.
- [ ] **Live Performance Mode:** A ultra-lean, high-stability boot mode specifically for live stage use.

---

## How to Contribute
Roadmaps are living documents. If you have ideas or want to help us reach these milestones faster:
1. Open a **Feature Request** on GitHub.
2. Join the discussion in our **Discourse/Matrix** (links coming soon).
3. Check the **Contributing** section in the `README.md`.
