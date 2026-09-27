# Roadmap

- [x] Reproducible Nix development shell and CMake build.
- [x] Native app bundle with projectM rendering a bundled original preset.
- [x] Deterministic synthetic audio for renderer verification.
- [x] Open user .milk presets and folders; fullscreen and preset navigation.
- [x] Core Audio system-output capture, user permission flow, and useful errors.
- [x] Automated rendering smoke test that checks actual nonblack pixels.
- [x] Audio buffering tests for channel conversion, overflow, and silence.
- [ ] Manual checks with real music, multiple sample rates, device switching and permission denial.
- [x] Relocatable development bundle (no Nix-store runtime dependencies).
- [ ] Public release packaging: complete dependency notices/source delivery, signing and notarization.
- [ ] Preset compatibility corpus and performance measurements.
- [ ] Assess `.milk2` format and double-preset mixing separately; no support claimed yet.
- [ ] Compare MD3 extensions (q33–q64, 16 waves/shapes, transitions, mashups) with projectM.
- [ ] Decide future Metal strategy after the native prototype is working.
- [ ] Intel macOS testing if required.

## Preset library

- [x] Install the pinned Cream of the Crop collection (9,795 presets).
- [x] Timed no-repeat shuffle with selectable intervals and persistent settings.
- [x] Shared texture pack lookup with an optional custom texture directory.
- [x] Searchable native preset browser with name/category filtering and keyboard playback.
- [x] Positive and negative GPU tests proving external textures are used.
- [ ] Broader preset compatibility/performance sweep; isolate native failures in a separate test process.
- [ ] Favorites, playback history, and a persistent user-managed exclusion list.
- [ ] Optional shuffle of browser search results (currently the selected collection is shuffled).
- [ ] Preset thumbnails and richer metadata.
