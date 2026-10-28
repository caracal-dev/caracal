#!/bin/bash
# Fire the system-level greeter sync (allowed via the 10-dms-greeter-sync
# polkit rule). Runs at session start and whenever the watched DMS config
# files change (dms-watch.path).
set -e
systemctl start dms-greeter-sync.service