#!/usr/bin/env bash
set -euo pipefail
# Separate, pinned upstream checkouts preserve original authorship and notices.
asset_root="${MILKDROP_ASSET_DIR:-$HOME/Library/Application Support/MilkDrop macOS}"
mkdir -p "$asset_root/Collections" "$asset_root/Textures"
staging=''
trap 'if [[ -n "$staging" && -d "$staging" ]]; then rm -rf "$staging"; fi' EXIT
install_checkout() {
  local url="$1" revision="$2" destination="$3"
  if [[ -e "$destination" ]]; then
    if [[ "$(git -C "$destination" rev-parse HEAD 2>/dev/null || true)" == "$revision" ]]; then
      echo "Already installed: $destination"
      return
    fi
    echo "Refusing to replace existing content: $destination" >&2
    exit 1
  fi
  staging="$(mktemp -d "$asset_root/.download.XXXXXX")"
  git -C "$staging" init -q
  git -C "$staging" remote add origin "$url"
  git -C "$staging" fetch -q --depth 1 origin "$revision"
  git -C "$staging" checkout -q --detach FETCH_HEAD
  mv "$staging" "$destination"
  staging=''
  echo "Installed: $destination"
}
install_checkout https://github.com/projectM-visualizer/presets-cream-of-the-crop.git \
  0180df21f5e0bd39b9060cc5de420ed2f1f9e509 "$asset_root/Collections/Cream of the Crop"
install_checkout https://github.com/projectM-visualizer/presets-milkdrop-texture-pack.git \
  6368812f27bc747b517218fbf89d21d59afce4d9 "$asset_root/Textures/MilkDrop"
echo 'Restart the app to discover the installed collection automatically.'
