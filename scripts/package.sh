#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Produce local sharing artifacts, not a signed/notarized public release.
output="${1:-$PWD/work/releases}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo 'Commit changes before packaging so the included source identifies the build exactly.' >&2
  exit 1
fi
./scripts/install-assets.sh
./scripts/build.sh
if [[ "$(lipo -archs build/MilkDropMac.app/Contents/MacOS/MilkDropMac)" != arm64 ]]; then
  echo 'This packaging configuration currently supports arm64 builds only.' >&2
  exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo 'The build changed tracked sources; commit them before packaging.' >&2
  exit 1
fi

mkdir -p work
stage="$(mktemp -d "$PWD/work/package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/root/Applications/MilkDropMac.app"
mkdir -p "$(dirname "$app")"
ditto --noextattr --noqtn build/MilkDropMac.app "$app"
resources="$app/Contents/Resources"
asset_root="${MILKDROP_ASSET_DIR:-$HOME/Library/Application Support/MilkDrop macOS}"
copy_collection() {
  local relative="$1" revision="$2"
  mkdir -p "$resources/Assets/$relative"
  # Archive the pinned revision, excluding checkout metadata and local changes.
  git -C "$asset_root/$relative" archive "$revision" | tar -xf - -C "$resources/Assets/$relative"
}
copy_collection 'Collections/Cream of the Crop' 0180df21f5e0bd39b9060cc5de420ed2f1f9e509
copy_collection 'Textures/MilkDrop' 6368812f27bc747b517218fbf89d21d59afce4d9

# Include the complete corresponding application/renderer/dependency sources,
# build instructions, and embedded upstream copyright/license notices.
mkdir -p "$resources/Source"
git ls-files --recurse-submodules -z > "$stage/sources.list"
COPYFILE_DISABLE=1 tar --null -czf "$resources/Source/milkdrop-macos-source.tar.gz" -T "$stage/sources.list"
{
  echo 'Application source: https://github.com/elucid/milkdrop-macos'
  git rev-parse HEAD
  git submodule status --recursive
  echo 'Presets: https://github.com/projectM-visualizer/presets-cream-of-the-crop'
  echo '0180df21f5e0bd39b9060cc5de420ed2f1f9e509'
  echo 'Textures: https://github.com/projectM-visualizer/presets-milkdrop-texture-pack'
  echo '6368812f27bc747b517218fbf89d21d59afce4d9'
  echo 'The source archive includes build instructions and upstream notices.'
} > "$resources/Source/Provenance.txt"
cp packaging/Read\ Me.html "$resources/Read Me.html"

# Seal the completed bundle for integrity. Ad-hoc signing is NOT Developer ID
# signing or notarization and does not bypass Gatekeeper on another Mac.
codesign --force --sign - "$app/Contents/Frameworks/libprojectM-4.4.dylib"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
name="MilkDropMac-$version-arm64-complete"
ditto -c -k --keepParent --noextattr --noqtn "$app" "$output/$name.zip"

# Disable relocation: the installer must install into /Applications, never
# follow a matching development copy found elsewhere on the sender's Mac.
pkgbuild --analyze --root "$stage/root" "$stage/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$stage/components.plist"
pkgbuild --root "$stage/root" --component-plist "$stage/components.plist" \
  --identifier com.elucid.milkdrop-macos --version "$version" \
  --install-location / "$stage/MilkDropMac-component.pkg"
productbuild --distribution packaging/Distribution.xml --resources packaging \
  --package-path "$stage" "$output/$name.pkg"
cp packaging/Read\ Me.html "$output/Read Me.html"
(cd "$output" && shasum -a 256 "$name.pkg" "$name.zip" > SHA256SUMS.txt)
echo "Created $output/$name.pkg and $output/$name.zip"
