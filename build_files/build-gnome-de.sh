#!/bin/bash
# Caracal GNOME desktop-environment setup.
# Runs inside the Silverblue-based caracal-gnome image, after the shared
# package installs in build.sh. Intel/AMD only — no NVIDIA variant yet.
#
# Pattern follows ublue-os/bazzite's GNOME branch: strip the Fedora GNOME
# default apps that Caracal replaces (Bazaar, its own setup wizard), add the
# few GNOME-native helpers, compile the vendored AppIndicator extension and
# our gschema overrides, and leave GDM as the display manager.

set -ouex pipefail

gnome_gui_packages=(
  firewall-config
  libappindicator-gtk3
  libayatana-appindicator-gtk3
  openssh-askpass
)

# Fedora GNOME defaults that Caracal does not need or replaces:
# gnome-software      -> replaced by Bazaar (Flatpak)
# gnome-initial-setup -> replaced by the Caracal setup wizard
# gnome-tour          -> no interactive tour; Caracal setup covers first run
# gnome-system-monitor -> replaced by mission-center-style tooling later; keep the image lean
# gnome-shell-extension-* -> stock extensions that clutter a curated desktop
gnome_packages_to_remove=(
  gnome-classic-session
  gnome-extensions-app
  gnome-initial-setup
  gnome-software
  gnome-system-monitor
  gnome-tour
  gnome-shell-extension-apps-menu
  gnome-shell-extension-background-logo
  gnome-shell-extension-launch-new-instance
  gnome-shell-extension-places-menu
  gnome-shell-extension-window-list
)

dnf5 -y install "${gnome_gui_packages[@]}"
dnf5 -y remove "${gnome_packages_to_remove[@]}" || true

# Compile GNOME Shell schemas. glib-compile-schemas ships in glib2-devel.
# (kinoite pulls it transitively; GNOME does not, so install and remove it
# around the compile step to keep the final image lean.)
dnf5 -y install glib2-devel

# Vendored AppIndicator + KStatusNotifierItem extension (system tray for the
# Caracal audio controller and other Qt AppIndicator apps).
glib-compile-schemas \
  /usr/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas

# Keep Caracal Audio Controller tray-only in GNOME. The RPM ships a launcher
# entry (/usr/share/applications/caracal-audio-controller.desktop) alongside
# its autostart file, so it appears in the app grid here; scope it to KDE,
# where the launcher entry stays as-is. The autostart copy is tracked
# NoDisplay in system_files/gnome/etc/xdg/autostart/, and NoDisplay does not
# affect autostart, so the tray icon is preserved.
if [[ -f /usr/share/applications/caracal-audio-controller.desktop ]]; then
  sed -i '/^OnlyShowIn=/d; /^Categories=/a OnlyShowIn=KDE;' \
    /usr/share/applications/caracal-audio-controller.desktop
fi

# Caracal defaults: default wallpaper (caracal-silloutte), favorite apps,
# enabled extensions, dark color scheme. Recompile so the overrides apply.
rm -f /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

# GDM login-screen wallpaper (caracal-silloutte) via the gdm system dconf
# database: the keyfile ships in system_files/gnome/etc/dconf/db/gdm.d/ and
# must be compiled here so the greeter renders it instead of the Fedora
# default (the gdm user's session reads system-db:gdm — see
# /etc/dconf/profile/gdm). dconf is a gnome-shell dependency; pull it in
# explicitly (hermetic, same pattern as glib2-devel) if the base drops it.
command -v dconf >/dev/null || dnf5 -y install dconf
dconf update

dnf5 -y remove --no-autoremove glib2-devel || true