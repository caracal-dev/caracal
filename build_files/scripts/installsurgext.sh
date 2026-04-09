#!/usr/bin/env bash
set -euo pipefail
rpm_url="https://github.com/surge-synthesizer/releases-xt/releases/download/1.3.4/surge-xt-x86_64-1.3.4.rpm"
dnf install -y --nogpgcheck "$rpm_url"
