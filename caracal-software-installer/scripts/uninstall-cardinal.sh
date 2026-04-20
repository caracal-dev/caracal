#!/usr/bin/env bash
set -euo pipefail

rm -f /usr/local/bin/Cardinal
rm -f /usr/local/bin/CardinalJACK
rm -rf /usr/local/lib64/vst/Cardinal.vst
rm -rf /usr/local/lib64/vst3/Cardinal.vst3
rm -rf /usr/local/lib64/vst3/CardinalFX.vst3
rm -rf /usr/local/lib64/vst3/CardinalSynth.vst3
rm -rf /usr/local/lib64/lv2/Cardinal.lv2
rm -rf /usr/local/lib64/lv2/CardinalFX.lv2
rm -rf /usr/local/lib64/lv2/CardinalSynth.lv2
rm -rf /usr/local/lib64/lv2/CardinalMini.lv2
rm -rf /usr/local/lib64/clap/Cardinal.clap

echo "Cardinal removed."
