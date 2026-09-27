# Third-party software

- **projectM v4.1.7**: https://github.com/projectM-visualizer/projectm . Renderer, dynamically linked; see `vendor/projectm/LICENSE.txt` and the license files in its dependencies. The submodule pins the exact source used.
- projectM includes additional dependencies with their own notices. Keep upstream notices with source and include applicable notices and corresponding source information in binary distributions.
- This source repository does not include proprietary MilkDrop3 binaries, presets, or assets. The two demo presets authored here are covered by the frontend's MIT license.

Distribution packaging and its complete license inventory are tracked in docs/TODO.md.

## Optional locally installed assets

`scripts/install-assets.sh` installs separate upstream Git checkouts, including their notices:

- Cream of the Crop: https://github.com/projectM-visualizer/presets-cream-of-the-crop , revision `0180df21f5e0bd39b9060cc5de420ed2f1f9e509`.
- MilkDrop texture pack: https://github.com/projectM-visualizer/presets-milkdrop-texture-pack , revision `6368812f27bc747b517218fbf89d21d59afce4d9`.

These community assets retain their original authorship and upstream notices; the frontend's MIT license does not apply to them. They are not checked into this source repository or included in ordinary development builds. The local complete-package script copies the pinned upstream trees into `Contents/Resources/Assets`, including original notices. Refer to each upstream collection for its terms and provenance; this project does not independently assert that community assets are public domain.

## Complete local packages

The package script includes `Contents/Resources/Source/milkdrop-macos-source.tar.gz`: all tracked application, projectM, and recursive submodule sources, build files, and their embedded copyright/license notices. `Provenance.txt` records exact revisions. projectM remains a separate dynamically linked library under `Contents/Frameworks`; the app uses ad-hoc signing without hardened-runtime library validation. Sources include the renderer's vendored evaluator, HLSL parser, GLM, and SOIL2/stb code and their respective notices. A consolidated notice inventory and public-release review remain on the roadmap.
