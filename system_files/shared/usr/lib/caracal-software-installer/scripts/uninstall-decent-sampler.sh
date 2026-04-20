#!/usr/bin/env bash
set -euo pipefail

rm -f /usr/local/bin/DecentSampler
rm -f /usr/local/lib64/vst/DecentSampler.so
rm -rf /usr/local/lib64/vst3/DecentSampler.vst3

echo "Decent Sampler removed."
