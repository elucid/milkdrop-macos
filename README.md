# MilkDrop macOS

A native macOS music visualizer powered by [projectM](https://github.com/projectM-visualizer/projectm), inspired by MilkDrop. This is an independent application, not an official MilkDrop3 port. It currently supports classic `.milk` presets; modern MilkDrop3 extensions and `.milk2` files are not supported.

## What works

- Native AppKit window, Retina rendering and fullscreen.
- projectM 4.1.7 rendering, including HLSL preset shaders translated to GLSL.
- Two original demo presets, opening a `.milk` file, and browsing a preset folder with Next Preset.
- Opt-in system-output capture through Core Audio taps, plus synthetic demo audio.
- Nix/CMake build without full Xcode, tested on an Apple M5 Max running macOS 26.5.1.

## Build and run

Requires Nix with flakes enabled and macOS 14.2 or newer. Apple Silicon is tested; Intel is not yet tested. Nix supplies the compiler, linker and SDK; this does not require installing the Xcode app.

```sh
git clone --recurse-submodules https://github.com/elucid/milkdrop-macos.git
cd milkdrop-macos
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

## Use

The app starts with **synthetic demo audio**; it does not play sound.

| Action | Control |
| --- | --- |
| Open `.milk` preset | File → Open Preset / ⌘O |
| Open preset folder (includes subfolders) | File → Open Preset Folder / ⇧⌘O |
| Next preset | Bottom button / ⌘N |
| Fullscreen | View → Toggle Full Screen / ⌃⌘F |
| Switch demo / system audio | Bottom button / ⌘A |

System Audio visualizes sound from other apps. macOS may ask for system-audio recording permission. Capture does not mute playback, write audio to disk, or transmit audio. Select the button again to stop capture and return to demo mode.

If no samples arrive, start music and check System Settings → Privacy & Security → Screen & System Audio Recording. The tap may wait until an app starts playing. Zero-level input can mean silence or missing permission. After changing devices or permissions, stop and restart capture. Capture currently supports mono/stereo Float32 PCM; device-change recovery is not yet automatic.

## Verification

`./scripts/build.sh` builds the app and runs the audio tests: buffering, overflow, concurrent ordering, channel layouts, silence, invalid samples, and resampling at five rates.

Run `./scripts/smoke-test.sh` in a logged-in graphical macOS session to render both presets, verify nonblack and changing GPU pixels, check OpenGL errors, and save PNGs under `work/`. It also verifies that an invalid preset fails. These tests open temporary windows and time out after 20 seconds per case. They do not capture system audio or require recording permission.

## Project notes

See the [development log](docs/DEVELOPMENT.md), [remaining tasks](docs/TODO.md), and [third-party notices](THIRD_PARTY.md). The renderer is pinned as a Git submodule; its evaluator is pinned recursively. Keep submodules intact when cloning.

The frontend and original demo presets are MIT licensed. projectM remains under its upstream licenses, principally LGPL-2.1-or-later. No proprietary MilkDrop3 release assets are bundled. Public binary distribution and a complete dependency-notice inventory remain tracked release tasks.
