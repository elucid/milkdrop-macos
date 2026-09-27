# Third-party software

- **projectM v4.1.7**: https://github.com/projectM-visualizer/projectm . Renderer, dynamically linked; see `vendor/projectm/LICENSE.txt` and the license files in its dependencies. The submodule pins the exact source used.
- projectM includes additional dependencies with their own notices. Keep upstream notices with source and include applicable notices and corresponding source information in binary distributions.
- This repository does not include proprietary MilkDrop3 binaries, presets, or assets. Any bundled presets authored here are covered by the frontend's MIT license.

Distribution packaging and its complete license inventory are tracked in docs/TODO.md.

## Optional locally installed assets

`scripts/install-assets.sh` installs separate upstream Git checkouts, including their notices:

- Cream of the Crop: https://github.com/projectM-visualizer/presets-cream-of-the-crop , revision `0180df21f5e0bd39b9060cc5de420ed2f1f9e509`.
- MilkDrop texture pack: https://github.com/projectM-visualizer/presets-milkdrop-texture-pack , revision `6368812f27bc747b517218fbf89d21d59afce4d9`.

These community assets retain their original authorship and upstream notices; the frontend's MIT license does not apply to them. They are not redistributed inside this repository or the app bundle. Refer to each upstream collection for its terms and provenance.
