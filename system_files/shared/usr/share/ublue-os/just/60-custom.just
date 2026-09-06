# Caracal OS ujust recipes
# Import each topical just file. Keep this file as the single entry point.
#
# Recipe numbering follows Bazzite conventions:
#   10-49   Caracal-specific base utilities
#   60-69   First-run / setup
#   70-79   Flatpaks
#   80-89   Domain-specific (DAW, plugins, VM, Waydroid)

import "/usr/share/ublue-os/just/10-caracal-helper.just"
import "/usr/share/ublue-os/just/20-caracal-cli.just"
import "/usr/share/ublue-os/just/30-caracal-dx.just"
import "/usr/share/ublue-os/just/60-caracal-firstrun.just"
import "/usr/share/ublue-os/just/70-caracal-flatpaks.just"
import "/usr/share/ublue-os/just/80-caracal-daw.just"
import "/usr/share/ublue-os/just/82-caracal-waydroid.just"
import "/usr/share/ublue-os/just/83-caracal-audio.just"
import "/usr/share/ublue-os/just/84-caracal-virt.just"
import "/usr/share/ublue-os/just/85-caracal-plugins.just"