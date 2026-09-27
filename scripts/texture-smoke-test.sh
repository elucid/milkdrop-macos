#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work
app="$PWD/build/MilkDropMac.app/Contents/MacOS/MilkDropMac"
fixture="$PWD/tests/fixtures/shared-texture.milk"
"$app" --preset "$fixture" --smoke-test "$PWD/work/shared-texture.png"
# The same shader must fail the pixel/motion check without the shared pack.
if MILKDROP_ASSET_DIR="$PWD/work/nonexistent-assets" "$app" --preset "$fixture" --smoke-test "$PWD/work/missing-texture.png"; then
  echo 'FAIL: the texture fixture rendered without its external texture' >&2
  exit 1
fi
