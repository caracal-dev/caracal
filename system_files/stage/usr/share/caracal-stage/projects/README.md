# Caracal Stage — Carla projects

This directory holds Carla project files (`.carxp` / saved state) that
`caracal-audio-daemon` and `carla-adapter.py` operate on. The daemon
persists the **live chain + presets** separately under
`/var/lib/caracal-audio-daemon/state.json`, so the chain survives a daemon
rebuild.

On the kiosk image, this directory ships empty. `ujust first-run` populates
the per-user plugin folders (`~/.vst3/`, `~/.lv2/`, `~/.clap/`, `~/.vst/`)
and runs `carla-discover.py --params` once to enumerate Carla's plugin
cache. The discovered catalog is what the daemon surfaces to the UI.

If you need to pre-stage a custom rig set (e.g. a fixed guitar chain per
venue), drop a `catalog.json` matching the daemon's `Config.CatalogEntry`
schema into this directory and update
`/etc/caracal-audio-daemon/config.json` to point at it via the
`CARACAL_AUDIO_DAEMON_CATALOG` env var in
`/usr/lib/systemd/user/caracal-audio-daemon.service`.
