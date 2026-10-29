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

- [x] **Caracal Software Installer Catalog Expansion:** Adding more curated Linux-native plugins (CLAP, VST3, LV2) to the Software Installer.
- [x] **Streamlined First-Run:** Enhancing `ujust first-run` with a graphical or interactive setup wizard for hardware selection.
- [x] **Hardware Quirk Database:** Expanding `/usr/lib/modprobe.d/` with more specific quirks for professional USB and FireWire interfaces.
- [x] **DAW Configuration Templates:** Pre-optimized project templates for included DAWs to minimize setup time.
- [ ] **Documentation Wiki:** Detailed guides on Yabridge management, Homebrew integration, and low-latency troubleshooting.
- [x] **Flatpak Volume Normalization:** Finalizing system-wide PipeWire/WirePlumber rules for consistent audio levels across apps.

---

## 🔐 Phase 2.5: Image Signing & Build Infrastructure (In Progress)

Shipping verified images and hardening the build pipeline, following the Titanoboa installer change.

- [x] **Image Signature Verification (Titanoboa):** All published images are cosign-signed; the verification policy and public key ship in `/etc` of every image, enabling `--enforce-container-sigpolicy` at install or upgrade time.
- [x] **Legacy Install Migration:** `install-sigpolicy.sh` one-liner for pre-titanoboa installs blocked by the stock `insecureAcceptAnything` policy (signed transport refuses unverified updates).
- [x] **Signing Key Rotation & Alignment:** Fresh keypair with `SIGNING_SECRET` and `cosign.pub` aligned across the dev fork and main repo; verified end-to-end on a legacy test install.
- [x] **Known-Issue Triage:** Bug-report template with a "known fix first" checklist (policy/signature errors → run the migration one-liner) and required `bootc status` / `bootc upgrade --check` output.
- [ ] **build.sh Decomposition:** Move static package installs into cache-mounted Containerfile `RUN` steps and the kcm-caracal-audio compile into its own builder stage; slim `build.sh` down to dynamic logic (rsync, branding, systemd enables, policy). Goal: change-scoped rebuilds and cross-variant layer reuse across all image flavors.
- [ ] **Enforced-by-Default Installs:** Flip the installer from `--no-signature-verification` to `--enforce-container-sigpolicy` for new installs (matches current upstream Bazzite posture) now that the signing pipeline is proven.

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
