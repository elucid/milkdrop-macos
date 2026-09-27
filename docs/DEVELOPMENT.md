# Development log

## 2026-09-26 — feasibility and starting point

- User approved a projectM-based native macOS application after investigating MilkDrop3.
- MilkDrop3 `code/` last changed in April 2023. Maintainer confirms it is an old alpha: https://github.com/milkdrop2077/MilkDrop3/issues/63#issuecomment-2041618757 . Current release parity requires independent implementation or newer source.
- Original source uses Direct3D 9, D3DX HLSL compilation, WASAPI, Win32 UI, and an architecture-specific NS-EEL engine. Porting it directly would be a substantial rewrite.
- Local machine: arm64, macOS 26.5.1, Apple M5 Max. Apple Command Line Tools are already installed; no full Xcode at /Applications/Xcode.app.
- A scratch probe built with Nix Clang 21.1.8, Nix linker and Nix macOS SDK 14.4 successfully instantiated AppKit and Core Audio objects and compiled a Metal shader at runtime. No audio was captured in that probe.
- Chosen renderer: projectM v4.1.7 (e0b0a967f0ffd7d332106c366668ed271718472b), latest stable release at investigation time. Preserve upstream as a submodule to make provenance and future updates explicit.
- Initial architecture: AppKit + Objective-C++, projectM C API, OpenGL 4.1 context. Keep renderer and capture replaceable. macOS OpenGL is deprecated; a Metal migration remains a future architectural decision.
- Initial build target: Apple Silicon, macOS 14.2 or newer, Nix + CMake/Ninja. Intel support is untested.
- Toolchain note: the user's `cc` command launches an unrelated CLI; use explicit Nix compiler selection through the development shell.

## Working practice

Commit and push small working milestones. Record the exact checks performed, known limitations, and unresolved issues here; keep remaining tasks in TODO.md. Never label synthetic input as system audio, or a frontend around projectM as full MilkDrop3 compatibility.

## 2026-09-26 — renderer builds with Nix

- Created and pushed https://github.com/elucid/milkdrop-macos .
- Locked Nixpkgs and selected its macOS SDK 15.5 (supports Core Audio taps); explicit Clang variables avoid the local `cc` alias.
- `nix develop -c sh -c 'cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build build -j 8'` succeeded: 91 build steps, unmodified projectM 4.1.7 and its pinned evaluator, ARM64 dynamic library.
- No full Xcode used. Nix fetched its SDK from the binary cache.

## 2026-09-26 — first native rendering

- Added an AppKit/NSOpenGLView application with Retina backing resolution, fullscreen, preset opening and navigation, error reporting, and synthetic stereo input.
- Original Aurora and Prism presets are MIT licensed; Prism exercises projectM's HLSL-to-GLSL shader translation.
- Added `--smoke-test` with framebuffer readback, nonblack-pixel and temporal-change assertions, preset failure tracking, OpenGL error checking, and PNG output.
- Aurora passed at 2000×1276 on the M5 Max: 1,657,219 lit pixels, 2,137,169 changed pixels, no GL errors. Visually inspected the PNG; it shows a flowing green/cyan ring.
- Disabled CMake's FLEX/BISON discovery: the evaluator otherwise rewrites checked-in scanner files using the host tools. Restored only the generated files modified by our build; submodules remain unmodified.
- Prism passed at 2000×1276: 1,138,113 lit pixels, 1,709,592 changed pixels, no GL errors. The missing-file case returned failure as expected, preventing false positives from projectM's fallback preset.

## 2026-09-26 — system audio capture

- Implemented a private, unmuted Core Audio global stereo process tap and a private aggregate capture device. Capture is opt-in via the Audio menu or bottom button; stopping destroys the callback, aggregate device, and tap.
- Audio callback uses a bounded lock-free SPSC ring, no allocations and no projectM calls. All renderer calls remain on the main thread. Silence is submitted when capture has no samples; synthetic audio is never substituted while capture is active.
- Supports packed Float32 mono/stereo, planar or interleaved. Linear streaming resampling to 44.1 kHz is for visualization only, not high-fidelity audio playback; out-of-range/NaN input is sanitized.
- `ctest --test-dir build --output-on-failure` passed: ring overflow/wrap, 100,000-frame producer/consumer ordering, mono/stereo/planar/silent channel reads, invalid samples, and ramp interpolation at 22.05/44.1/48/96/192 kHz.
- Reran GPU smoke suite successfully for Aurora, Prism and expected rejection of a missing preset.
- Manual UI verification: Next Preset updates Aurora → Prism; fullscreen enters/exits; capture starts/stops. A locally generated quiet stereo tone played with `afplay` was captured at 48 kHz and the UI reported 2% peak (matching its amplitude). No captured audio is written to disk.
- Core Audio tap auto-start means no callbacks before an application starts playing. The UI distinguishes waiting for audio from actual receipt. Zero-level buffers may mean silence or missing permission; do not claim permission success solely from callback receipt.
- Still untested: permission denial/revocation, Bluetooth/default-output changes, sustained capture over long sessions, Intel builds and macOS 14.2 hardware.

## 2026-09-26 — development bundle and preset folders

- Added asynchronous recursive `.milk` folder discovery and a dedicated menu command; skip hidden files and package directories, sort naturally, and explain empty folders without claiming `.milk2` support.
- Raised the minimum window width to keep audio controls accessible.
- Added `scripts/build.sh` for recursive submodule setup, Nix build, and audio checks.
- Bundled the projectM dylib under Contents/Frameworks and changed the executable's only rpath to `@executable_path/../Frameworks`. `otool -L` confirms the app and renderer otherwise link only Apple system libraries/frameworks. No Nix runtime dependency remains.
- Resources refresh on every normal build, including changes to presets alone. Bundled primary frontend/projectM/evaluator/HLSL parser licenses and source provenance; the full transitive notice inventory remains a task before public binary releases.
- Audio tests pass after packaging changes. Native deployment target is 14.2, but runtime validation so far is only on macOS 26.5.1.
- Relocation verification: copied the .app under `work/relocation-check/`, unset DYLD library-path overrides, and ran its bundled-preset smoke test. Passed at 2000×1276 with 1,643,223 lit pixels, 2,152,104 changed pixels, no GL errors.
- Final manual folder check: ⇧⌘O opened the native folder panel, selecting `resources/presets` loaded Aurora, and Next Preset switched to Prism. Left the normal development app open in demo mode for the user.

## 2026-09-26 — external preset and texture collections

- Added an idempotent asset installer with pinned Git revisions and atomic staging. It preserves upstream checkouts/notices outside our MIT source and refuses to replace unexpected existing content.
- Installed Cream of the Crop (0180df21f5e0bd39b9060cc5de420ed2f1f9e509) and the MilkDrop texture pack (6368812f27bc747b517218fbf89d21d59afce4d9) under `~/Library/Application Support/MilkDrop macOS/`.
- These are separately authored assets; we do not relabel them MIT or infer public-domain status from the upstream collection's license note. Keep their original provenance/notices; they are not bundled in our public app binaries.

## 2026-09-26 — shuffle, shared textures and library browser

- Discover the installed collection at launch, or restore a previously chosen folder. Scan off the UI thread; reject stale scan results when another folder was selected meanwhile.
- Added a randomized no-repeat deck, automatic switching (30 seconds by default; 10/15/30/60/120 selectable), a countdown, smooth two-second transitions, manual shuffle and persistent settings. Manual selection restarts the interval. Pause countdown while minimized, showing a sheet, or searching in the browser.
- Presets with reported load errors are skipped for the session. After eight consecutive attempted loads fail, pause rather than stall the interface. This cannot protect against a native crash inside projectM or a GPU driver.
- Added shared texture lookup: preset-local assets first, collection `textures/`, an optional custom folder, then the installed texture pack. Avoid recreating the texture manager when paths haven't changed; remove a redundant second reset.
- Split renderer, library model, shuffle deck and browser out of the main controller. Added case/diacritic-insensitive multiword name/category search and a virtualized native table with double-click/Return playback.
- Library tests exposed the `/var` versus `/private/var` path alias. Canonicalize existing paths with realpath to preserve relative categories and deduplicate texture paths.
- Audio tests and library/shuffle tests pass. GPU smoke tests pass for both demo presets and reject the missing-file case.
- New external-texture fixture: 2,921,600 lit pixels and 2,921,519 changing pixels with the pack; zero lit/changed pixels when the asset root is hidden. Both outcomes are asserted by `scripts/texture-smoke-test.sh`.
- Correction to the initial demo verification: Prism was missing its MilkDrop 2 shader-version header, so the original smoke test demonstrated rendering but did not prove its composite shader ran. Added explicit version headers to Prism and the texture fixture; the shader path is now exercised and passes.
- Manual checks so far: all 9,795 presets discovered, ten-second automatic switching changes the preset, manual shuffle resets countdown, browser search `martin fractal` returns 172 results, no-match search disables Play. Testing also revealed the original Cmd+A audio shortcut intercepted Select All; moved audio to Option+Cmd+A and added standard Edit commands.
- Final browser verification: Cmd+A now replaces the search text without switching audio. `martin mandel` returns 26 results; selecting `martin - castle in the air` and pressing Return loads it. Cmd+W closes the browser and resumes the countdown.
- Restart verified that the test interval (10 seconds) persisted. Restored 30 seconds afterward. Asset installer rerun correctly reports both checkouts already installed without replacing them.
- Left the final app running with all 9,795 presets, automatic 30-second shuffle, and system-audio mode restored. No assertion that every preset in the collection is compatible; broad batch validation remains a TODO.

## 2026-09-26 — portable collection discovery

- Added fallback discovery of `Contents/Resources/Assets` inside a transferred app. User-installed collections/textures retain priority; an explicit `MILKDROP_ASSET_DIR` remains isolated and disables bundled fallback.
- Added read-only `--check-assets` diagnostics so packaging can verify discovery without opening a window or changing preferences.
- Nix build and both existing test suites pass. Verified `CFFIXED_USER_HOME` isolates Foundation's Application Support lookup for a fresh-user packaging check; an app without bundled assets correctly reports no installed collection.

## 2026-09-26 — complete local sharing packages

- Added `scripts/package.sh` to rebuild/test from committed sources, archive pinned asset trees without Git metadata, include complete recursive corresponding source with revision provenance, ad-hoc sign the finished bundle, and produce a ZIP plus a script-free installer.
- The complete app reads its assets in place. Installer targets `/Applications` with bundle relocation disabled; it does not select or write any user's home directory. Distribution declares arm64/macOS 14.2+ requirements. No Apple Developer ID or notarization is claimed.
- Packaging remains local; only implementation and documentation are pushed to GitHub. Community notices stay attached to the assets, which are not relabeled MIT/public domain.
- Made the build helper stop on CMake/build failure instead of potentially reaching tests against stale binaries.
