#!/bin/bash
# Copy the active Wayland session's DMS theme, session state and wallpaper
# into the global greeter cache so dms-greeter reflects the user's theming
# (Kanagawa Dragon preset, Caracal wallpaper) on the login screen.
#
# DMS 2.0 file locations:
#   ~/.config/dms/settings.json   - theme and shell settings
#   ~/.local/state/dms/session.json - session state incl. wallpaperPath
#   ~/.local/state/dms-colors.json  - matugen color output
set -e

ACTIVE_USER=""
for sid in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
    TYPE=$(loginctl show-session "$sid" -p Type --value)
    STATE=$(loginctl show-session "$sid" -p State --value)

    if [ "$TYPE" = "wayland" ] && [ "$STATE" = "active" ]; then
        ACTIVE_USER=$(loginctl show-session "$sid" -p Name --value)
        break
    fi
done

if [ -z "$ACTIVE_USER" ]; then
    echo "No active Wayland session found; not syncing greeter."
    exit 0
fi

USER_HOME="$(getent passwd "$ACTIVE_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo "Could not resolve home for '$ACTIVE_USER'; not syncing greeter."
    exit 0
fi

GREETER_CACHE="/var/cache/dms-greeter"
mkdir -p "$GREETER_CACHE"

cp "$USER_HOME/.config/dms/settings.json" "$GREETER_CACHE/settings.json" || true
cp "$USER_HOME/.local/state/dms/session.json" "$GREETER_CACHE/session.json" || true
cp "$USER_HOME/.local/state/dms-colors.json" "$GREETER_CACHE/colors.json" || true

# The greeter user cannot traverse arbitrary wallpaper locations (user homes,
# external mounts): copy the wallpaper into the cache and repoint the synced
# session state at the copy.
WP=$(sed -n 's/.*"wallpaperPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$GREETER_CACHE/session.json" 2>/dev/null | head -n1)
if [ -n "$WP" ] && [ -f "$WP" ]; then
    cp "$WP" "$GREETER_CACHE/wallpaper.png"
fi
sed -i \
    's|"wallpaperPath"[[:space:]]*:[[:space:]]*"[^"]*"|"wallpaperPath": "'"$GREETER_CACHE"'/wallpaper.png"|g' \
    "$GREETER_CACHE/session.json" || true

chown -R greeter:greeter "$GREETER_CACHE"
chmod -R a+r "$GREETER_CACHE"