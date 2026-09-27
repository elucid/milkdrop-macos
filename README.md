# MilkDrop macOS

A native macOS music visualizer powered by [projectM](https://github.com/projectM-visualizer/projectm), inspired by MilkDrop. This is an independent application, not an official MilkDrop3 port. It currently supports classic `.milk` presets; modern MilkDrop3 extensions and `.milk2` files are not supported.

## What works

- Native AppKit window, Retina rendering and fullscreen.
- projectM 4.1.7 rendering, including HLSL preset shaders translated to GLSL.
- Cream of the Crop: 9,795 community presets, installed separately with the shared MilkDrop texture pack.
- Timed random shuffle without repeats within a cycle, selectable intervals, smooth transitions, and saved collection/settings.
- A searchable native preset browser, plus opening individual `.milk` files or folders. Two original demo presets remain available as a fallback.
- Opt-in system-output capture through Core Audio taps, plus synthetic demo audio.
- Nix/CMake build without full Xcode, tested on an Apple M5 Max running macOS 26.5.1.

## Build and run

Requires Nix with flakes enabled and macOS 14.2 or newer. Apple Silicon is tested; Intel is not yet tested. Nix supplies the compiler, linker and SDK; this does not require installing the Xcode app.

```sh
git clone --recurse-submodules https://github.com/elucid/milkdrop-macos.git
cd milkdrop-macos
./scripts/install-assets.sh
./scripts/build.sh
open build/MilkDropMac.app
```

Or work interactively:

```sh
nix develop
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j 8
ctest --test-dir build --output-on-failure
```

The app bundles its projectM dynamic library, so it can be moved out of the build directory. Runtime dependencies are Apple system frameworks/libraries; Nix is needed to build, not to run the resulting app. This remains a local development build, not a signed/notarized public release. Compatibility with older macOS versions still needs testing.

## Preset collection and textures

`./scripts/install-assets.sh` downloads pinned upstream checkouts into:

```text
~/Library/Application Support/MilkDrop macOS/
  Collections/Cream of the Crop/   # 9,795 .milk presets in themed subfolders
  Textures/MilkDrop/               # shared images used by presets
```

The installer preserves upstream source/notices, is safe to rerun, and refuses to overwrite an unexpected existing installation. Collections are not copied into this repository or app bundle. You can override the asset root with `MILKDROP_ASSET_DIR` when installing and launching from a shell.

At startup the app restores your selected collection, otherwise loads the installed Cream of the Crop pack, and falls back to the two demo presets if the pack is absent. **File → Use Cream of the Crop** switches back from another folder. **File → Open Preset Folder** lets you restrict shuffle to one category or use another collection.

Textures are searched in the preset's directory and its `textures` subfolder, the selected collection's `textures` directory, an optional custom texture directory, then the installed shared pack. Choose the optional directory with **File → Choose Shared Texture Folder**. Local textures take precedence; missing images may still produce a placeholder without a preset-load error.

## Use

The app starts with **synthetic demo audio**; it does not play sound.

| Action | Control |
| --- | --- |
| Open `.milk` preset | File → Open Preset / ⌘O |
| Open preset folder (includes subfolders) | File → Open Preset Folder / ⇧⌘O |
| Shuffle to another preset | Shuffle now / ⌘N |
| Enable/pause automatic shuffle | Auto shuffle / ⌘S |
| Select shuffle interval | 10, 15, 30, 60, or 120 seconds in the bottom bar |
| Browse/search presets | Browse Presets / ⌘B |
| Fullscreen | View → Toggle Full Screen / ⌃⌘F |
| Switch demo / system audio | Bottom button / ⌥⌘A |

Auto shuffle starts enabled at **30 seconds** on a fresh installation. Each shuffled cycle visits presets without repeats; it also avoids an immediate repeat across cycles. Selecting a preset manually starts a new cycle and resets the countdown. The last folder, interval, auto-shuffle setting, and optional texture directory are remembered. Minimized windows, open file dialogs, and the active preset browser pause the countdown; returning starts a full interval.

In the browser, search any combination of name/artist/category words, for example `martin fractal`. Search ignores case and accents. Double-click a result, press Return with the table focused, or click **Play Selected**. Close the browser with ⌘W to return to playback. Searching narrows the browser results, not the shuffle collection; choose a category folder to restrict shuffle.

Presets that report a loading error are skipped for the session. Repeated loading failures pause shuffle. We have not validated every community preset, and this cannot isolate native renderer crashes or GPU stalls.

System Audio visualizes sound from other apps. macOS may ask for system-audio recording permission. Capture does not mute playback, write audio to disk, or transmit audio. Select the button again to stop capture and return to demo mode.

If no samples arrive, start music and check System Settings → Privacy & Security → Screen & System Audio Recording. The tap may wait until an app starts playing. Zero-level input can mean silence or missing permission. After changing devices or permissions, stop and restart capture. Capture currently supports mono/stereo Float32 PCM; device-change recovery is not yet automatic.

## Verification

`./scripts/build.sh` builds the app and runs audio tests (buffering, concurrent ordering, channel layouts, silence, invalid samples, resampling at five rates) and library tests (shuffle cycles, recursive scanning, search, texture-path priority/deduplication, missing folders).

Run `./scripts/smoke-test.sh` in a logged-in graphical macOS session to render both presets, verify nonblack and changing GPU pixels, check OpenGL errors, and save PNGs under `work/`. It also verifies that an invalid preset fails. These tests open temporary windows and time out after 20 seconds per case. They do not capture system audio or require recording permission.

`./scripts/texture-smoke-test.sh` verifies an external texture actually renders and animates, then checks that hiding the asset root makes the same fixture fail. Install assets first.

## Project notes

See the [development log](docs/DEVELOPMENT.md), [remaining tasks](docs/TODO.md), and [third-party notices](THIRD_PARTY.md). The renderer is pinned as a Git submodule; its evaluator is pinned recursively. Keep submodules intact when cloning.

The frontend and original demo presets are MIT licensed. projectM remains under its upstream licenses, principally LGPL-2.1-or-later. No proprietary MilkDrop3 release assets are bundled. Public binary distribution and a complete dependency-notice inventory remain tracked release tasks.
