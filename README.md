# MilkDrop macOS

An early native macOS music visualizer built on [projectM](https://github.com/projectM-visualizer/projectm), inspired by MilkDrop. This is an independent application, not an official MilkDrop3 port. Modern MilkDrop3 features and `.milk2` compatibility are not promised.

## Development

The renderer is pinned to projectM v4.1.7 as a Git submodule. Clone recursively:

```sh
git clone --recurse-submodules https://github.com/elucid/milkdrop-macos.git
cd milkdrop-macos
```

A Nix development environment and native frontend are being brought up. Full Xcode is not required. See [development notes](docs/DEVELOPMENT.md) and the [roadmap](docs/TODO.md).

## Licensing

Our frontend is MIT licensed. projectM remains under its upstream licenses (principally LGPL-2.1); see [third-party notices](THIRD_PARTY.md). No MilkDrop3 release assets are bundled.

```sh
nix develop
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j 8
open build/MilkDropMac.app
```

The app initially uses **synthetic demo audio** (it does not play sound). Use File → Open Preset to load a `.milk` file, ⌘N to cycle the bundled presets, and ⌃⌘F for fullscreen.

Run `./scripts/smoke-test.sh` in a logged-in graphical macOS session to render both presets, verify nonblack and changing GPU pixels, check OpenGL errors, and save PNGs under `work/`. It also verifies that an invalid preset fails. The test opens temporary windows.

This is currently a development bundle referencing the build tree and Nix store, not a distributable release.
