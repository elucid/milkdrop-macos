#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
release="${1:-$PWD/work/releases}"
name=MilkDropMac-0.1.0-arm64-complete
mkdir -p work
stage="$(mktemp -d "$PWD/work/package-test.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
(cd "$release" && shasum -a 256 -c SHA256SUMS.txt)
pkgutil --expand-full "$release/$name.pkg" "$stage/installer"
ditto -x -k "$release/$name.zip" "$stage/zip"
app="$stage/zip/MilkDropMac.app"
installed="$stage/installer/MilkDropMac-component.pkg/Payload/Applications/MilkDropMac.app"
codesign --verify --deep --strict "$app"
codesign --verify --deep --strict "$installed"
diff -qr "$app" "$installed"
grep -F 'relocatable="false"' "$stage/installer/MilkDropMac-component.pkg/PackageInfo" > /dev/null
grep -F 'hostArchitectures="arm64"' "$stage/installer/Distribution" > /dev/null
grep -F 'os-version min="14.2"' "$stage/installer/Distribution" > /dev/null

# A fresh user's Foundation paths must resolve to bundled resources, even
# though the developer has an independent collection in Application Support.
unset MILKDROP_ASSET_DIR DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH
export CFFIXED_USER_HOME="$stage/fresh-home"
mkdir -p "$CFFIXED_USER_HOME"
exe="$app/Contents/MacOS/MilkDropMac"
"$exe" --check-assets > "$stage/assets.txt"
grep -Fx "Collection: $app/Contents/Resources/Assets/Collections/Cream of the Crop" "$stage/assets.txt"
grep -Fx 'Presets: 9795' "$stage/assets.txt"
grep -Fx "Texture path: $app/Contents/Resources/Assets/Textures/MilkDrop" "$stage/assets.txt"
otool -L "$exe" "$app/Contents/Frameworks/libprojectM-4.4.dylib" > "$stage/linkage.txt"
if grep -E '^[[:space:]]+(/nix/|/Users/)' "$stage/linkage.txt"; then
  echo 'FAIL: nonportable runtime dependency' >&2
  exit 1
fi
tar -tzf "$app/Contents/Resources/Source/milkdrop-macos-source.tar.gz" > "$stage/source-files.txt"
for source in src/main.mm vendor/projectm/CMakeLists.txt vendor/projectm/vendor/projectm-eval/LICENSE.md scripts/build.sh flake.lock; do
  grep -Fx "$source" "$stage/source-files.txt" > /dev/null
done

# An explicit override must not silently fall back to the bundled collection.
if MILKDROP_ASSET_DIR="$stage/missing" "$exe" --check-assets > "$stage/override.txt" 2>&1; then
  echo 'FAIL: explicit empty asset override was ignored' >&2
  exit 1
fi

# Preserve user collection precedence while still finding bundled textures.
personal="$CFFIXED_USER_HOME/Library/Application Support/MilkDrop macOS/Collections/Cream of the Crop"
mkdir -p "$personal"
cp resources/presets/Aurora.milk "$personal/Personal.milk"
"$exe" --check-assets > "$stage/personal.txt"
grep -Fx "Collection: $personal" "$stage/personal.txt"
grep -Fx 'Presets: 1' "$stage/personal.txt"
grep -Fx "Texture path: $app/Contents/Resources/Assets/Textures/MilkDrop" "$stage/personal.txt"

# Shader has no procedural fallback: it only draws the external paper texture.
"$exe" --preset "$PWD/tests/fixtures/shared-texture.milk" --smoke-test "$PWD/work/package-texture.png"
if MILKDROP_ASSET_DIR="$stage/missing" "$exe" --preset "$PWD/tests/fixtures/shared-texture.milk" --smoke-test "$PWD/work/package-missing-texture.png"; then
  echo 'FAIL: texture fixture rendered with the bundled pack hidden' >&2
  exit 1
fi
echo 'PASS: matching ZIP/installer payloads, signatures, portable linkage, bundled assets, overrides, user precedence, source delivery and texture rendering'
