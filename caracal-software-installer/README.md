# Caracal Software Installer

`caracal-software-installer` is a Go TUI built with `tview` for guided post-install setup on Caracal OS. It presents optional DAWs, instruments, plugins, and audio utilities in browsable categories and lets the user queue multiple installs in one pass.

## Current catalog

- DAWs
  - REAPER
  - Renoise
  - Bitwig Studio
- Virtual Instruments
  - Warmplace
    - SunVox
    - Virtual ANS
    - Fractal Bits (cataloged; upstream desktop download is purchase-gated)
  - TAL
    - TAL-Noisemaker
  - Cardinal
  - Surge XT
  - Loopino
  - Decent Sampler
- Effects
  - Audio Assault
    - Drum Locker
    - Amp Locker
    - Mix Locker
  - TAL effects section placeholder
- Utilities
  - RTCQS

The UI is catalog-driven, so adding more packages later is mostly a matter of dropping in scripts and extending the metadata in `internal/catalog`.

## Development

```bash
go mod tidy
go run ./cmd/caracal-software-installer
```

The app looks for installer scripts in:

1. `CARACAL_INSTALLER_SCRIPT_DIR`
2. `/usr/lib/caracal-software-installer/scripts`
3. `scripts/` in the current repo or a parent directory

Most package installs write to `/opt`, `/usr/local`, or the current user's home directory so they work on an atomic Caracal system without rpm layering.

## Contributing
Pull requests welcome. Just create a feature branch and submit a pull request with details about the change, what software you are adding to the catalog etc.

If you are currently running a Fedora Atomic image, you can clone this repo and run it locally and see if the installation you added work.

## TODO
1. ~~Add an uninstall option~~
2. Add sudo password and installation processing to happen within the program program so the user does not exit and then return.
3. Move all the Caracal default plugins and music software here and embed install into Caracal OS
4. Add more plugins
5. Fix general jank
