#!/usr/bin/env bash
# Applies Caracal OS branding to the image.
# Assets are available at /ctx/assets/ (bind-mounted from system_files/assets/).

set -oue pipefail

# Update OS identity in /usr/lib/os-release
sed -i 's|^PRETTY_NAME=.*|PRETTY_NAME="Caracal OS"|' /usr/lib/os-release
sed -i 's|^NAME=.*|NAME="Caracal OS"|' /usr/lib/os-release
# Replace ID=fedora with ID=caracal-os + add ID_LIKE=fedora on the next line
# (Kinoite's os-release has ID=fedora with no ID_LIKE, so we can't just replace ID_LIKE=)
sed -i 's|^ID=fedora|ID=caracal-os\nID_LIKE=fedora|' /usr/lib/os-release
sed -i 's|^LOGO=.*|LOGO=distributor-logo|' /usr/lib/os-release

# Install distributor logo (for KDE About This System, etc.)
mkdir -p /usr/share/icons/hicolor/scalable/places
cp /ctx/assets/logos/caracal.svg /usr/share/icons/hicolor/scalable/places/distributor-logo.svg

# Overwrite the kde-settings RPM's kcm-about-distrorc so "About This System" shows
# Caracal branding regardless of which path KDE searches first.
KDE_PROFILE_XDG="/usr/share/kde-settings/kde-profile/default/xdg"
mkdir -p "$KDE_PROFILE_XDG"
cp /etc/xdg/kcm-about-distrorc "$KDE_PROFILE_XDG/kcm-about-distrorc"

# Install wallpapers to the system wallpaper directory
mkdir -p /usr/share/wallpapers/caracal
cp /ctx/assets/wallpapers/* /usr/share/wallpapers/caracal/

# Install splash screen logo into Plasma look-and-feel packages
SPLASH_LOGO="/ctx/assets/logos/caracal-splash.svg"
cp "$SPLASH_LOGO" /usr/share/plasma/look-and-feel/com.valve.vapor.desktop/contents/splash/images/caracal-logo.svg
cp "$SPLASH_LOGO" /usr/share/plasma/look-and-feel/com.valve.vgui.desktop/contents/splash/images/caracal-logo.svg

# Plymouth boot splash: replace watermark with Caracal logo
# Remove Bazzite/Kinoite animation frames so only our watermark shows
rm -f /usr/share/plymouth/themes/spinner/animation-*.png
rm -f /usr/share/plymouth/themes/spinner/throbber-*.png
cp /ctx/assets/logos/caracal.png /usr/share/plymouth/themes/spinner/watermark.png

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
