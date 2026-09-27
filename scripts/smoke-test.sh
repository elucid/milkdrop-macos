#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work
app="$PWD/build/MilkDropMac.app/Contents/MacOS/MilkDropMac"
for preset in Aurora Prism; do
  "$app" --preset "$PWD/resources/presets/$preset.milk" --smoke-test "$PWD/work/$preset.png"
done
# A failed preset must fail the test even if projectM's fallback renders pixels.
if "$app" --preset "$PWD/work/does-not-exist.milk" --smoke-test "$PWD/work/missing.png"; then
  echo 'FAIL: missing preset was accepted' >&2
  exit 1
fi
