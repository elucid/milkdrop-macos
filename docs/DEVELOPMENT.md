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
