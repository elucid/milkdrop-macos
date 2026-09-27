# Roadmap

- [x] Reproducible Nix development shell and CMake build.
- [x] Native app bundle with projectM rendering a bundled original preset.
- [x] Deterministic synthetic audio for renderer verification.
- [ ] Open user .milk presets and folders; fullscreen and preset navigation.
- [x] Core Audio system-output capture, user permission flow, and useful errors.
- [x] Automated rendering smoke test that checks actual nonblack pixels.
- [x] Audio buffering tests for channel conversion, overflow, and silence.
- [ ] Manual checks with real music, multiple sample rates, device switching and permission denial.
- [ ] Relocatable release bundle (no Nix-store runtime dependencies), signing and notarization.
- [ ] Preset compatibility corpus and performance measurements.
- [ ] Assess `.milk2` format and double-preset mixing separately; no support claimed yet.
- [ ] Compare MD3 extensions (q33–q64, 16 waves/shapes, transitions, mashups) with projectM.
- [ ] Decide future Metal strategy after the native prototype is working.
- [ ] Intel macOS testing if required.
