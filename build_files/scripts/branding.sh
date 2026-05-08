#!/usr/bin/env bash
# Applies Caracal OS branding to the image.
# Assets are available at /ctx/assets/ (bind-mounted from system_files/assets/).

set -oue pipefail

# Update OS identity in /usr/lib/os-release
sed -i 's|^PRETTY_NAME=.*|PRETTY_NAME="Caracal OS"|' /usr/lib/os-release
sed -i 's|^NAME=.*|NAME="Caracal OS"|' /usr/lib/os-release
# Keep Fedora's distro ID so bootc-image-builder can resolve the correct
# manifest definitions (it keys off ID + VERSION_ID, e.g. fedora-43).
# Put the custom branding in variant fields instead.
if ! grep -q '^ID_LIKE=' /usr/lib/os-release; then
  sed -i '/^ID=fedora$/a ID_LIKE=fedora' /usr/lib/os-release
fi
if grep -q '^VARIANT=' /usr/lib/os-release; then
  sed -i 's|^VARIANT=.*|VARIANT="Caracal OS"|' /usr/lib/os-release
else
  printf '%s\n' 'VARIANT="Caracal OS"' >> /usr/lib/os-release
fi
if grep -q '^VARIANT_ID=' /usr/lib/os-release; then
  sed -i 's|^VARIANT_ID=.*|VARIANT_ID=caracal-os|' /usr/lib/os-release
else
  printf '%s\n' 'VARIANT_ID=caracal-os' >> /usr/lib/os-release
fi
sed -i 's|^LOGO=.*|LOGO=distributor-logo|' /usr/lib/os-release

# Install distributor logo (for KDE About This System, etc.)
mkdir -p /usr/share/icons/hicolor/scalable/apps /usr/share/icons/hicolor/scalable/places
cp /ctx/assets/logos/caracal.svg /usr/share/icons/hicolor/scalable/places/distributor-logo.svg
cp /ctx/assets/logos/caracal.svg /usr/share/icons/hicolor/scalable/apps/distributor-logo.svg

# KDE's application launcher commonly falls back to these icon names on existing
# user profiles, so provide aliases in addition to the explicit distributor logo.
cp /ctx/assets/logos/caracal.svg /usr/share/icons/hicolor/scalable/apps/start-here-kde.svg
cp /ctx/assets/logos/caracal.svg /usr/share/icons/hicolor/scalable/apps/start-here.svg

gtk-update-icon-cache -f /usr/share/icons/hicolor || true

# Overwrite the kde-settings RPM's kcm-about-distrorc so "About This System" shows
# Caracal branding regardless of which path KDE searches first.
KDE_PROFILE_XDG="/usr/share/kde-settings/kde-profile/default/xdg"
mkdir -p "$KDE_PROFILE_XDG"
cp /etc/xdg/kcm-about-distrorc "$KDE_PROFILE_XDG/kcm-about-distrorc"

# Install wallpapers to the system wallpaper directory
mkdir -p /usr/share/wallpapers/caracal
cp /ctx/assets/wallpapers/* /usr/share/wallpapers/caracal/

# Build a dedicated Caracal greeter theme from Fedora KDE's known-good SDDM
# theme, then apply our wallpaper override to that single theme.
rm -rf /usr/share/sddm/themes/caracal
cp -a /usr/share/sddm/themes/01-breeze-fedora /usr/share/sddm/themes/caracal
# Patch theme.conf directly — SDDM reads this from the theme directory.
# theme.conf.user at runtime is read from the sddm user's XDG data home
# (/var/lib/sddm/.local/share/sddm/themes/caracal/), NOT from here; a
# tmpfiles rule handles that deployment.
sed -i \
  -e 's|^background=.*|background=/usr/share/wallpapers/caracal/caracal-lake.png|' \
  -e 's|^type=.*|type=image|' \
  /usr/share/sddm/themes/caracal/theme.conf
# Fail the build explicitly if the sed didn't match (silent no-op otherwise).
grep -q '^background=/usr/share/wallpapers/caracal/caracal-lake.png' \
  /usr/share/sddm/themes/caracal/theme.conf
# Also write theme.conf.user into the theme dir for any SDDM builds that do
# search there, and as the source file for the tmpfiles copy rule.
cat > /usr/share/sddm/themes/caracal/theme.conf.user << 'EOF'
[General]
type=image
background=/usr/share/wallpapers/caracal/caracal-lake.png
EOF

# Install splash screen logo into the active Breeze Dark look-and-feel package.
# Caracal now uses Breeze Dark as the only supported default and ships its own
# splash assets inside that package.
SPLASH_LOGO="/ctx/assets/logos/caracal-splash.svg"
mkdir -p /usr/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/splash/images
cp "$SPLASH_LOGO" /usr/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/splash/images/caracal-logo.svg

# Plymouth boot splash
# Remove Bazzite/Kinoite animation frames so only our watermark shows.
rm -f /usr/share/plymouth/themes/spinner/animation-*.png
rm -f /usr/share/plymouth/themes/spinner/throbber-*.png
# Re-copy watermark after package installs — dnf may reinstall plymouth-theme-spinner
# and overwrite the rsync'd file before dracut runs.
cp /ctx/system_files/shared/usr/share/plymouth/themes/spinner/watermark.png \
   /usr/share/plymouth/themes/spinner/watermark.png

# Replace EFI boot picker icon with Caracal logo
mkdir -p /usr/share/pixmaps/bootloader
python3 -c "
import struct
with open('/usr/share/icons/hicolor/scalable/places/distributor-logo.svg', 'rb') as f:
    svg_data = f.read()
# For EFI, we use the PNG if available; embed PNG into ICNS ic09 slot
try:
    with open('/ctx/assets/logos/caracal.png', 'rb') as f:
        png_data = f.read()
    entry = b'ic09' + struct.pack('>I', 8 + len(png_data)) + png_data
    icns = b'icns' + struct.pack('>I', 8 + len(entry)) + entry
    with open('/usr/share/pixmaps/bootloader/fedora.icns', 'wb') as f:
        f.write(icns)
except Exception as e:
    print(f'ICNS creation skipped: {e}')
"
