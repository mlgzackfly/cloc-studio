# cloc-studio

`cloc-studio` is a macOS SwiftUI desktop app for visualizing code-count results from `cloc`.

## Upstream and attribution
This project is a GUI wrapper around **cloc** by Al Danial.

- Upstream project: https://github.com/AlDanial/cloc
- Upstream tool name: `cloc` (Count Lines of Code)
- Bundled runtime in this repo: `vendor/cloc`

Please keep this attribution when redistributing `cloc-studio`.

## License and compliance
`cloc` is distributed under GNU GPL (v2 or later, per upstream notices). Because this app bundles and redistributes `cloc`, releases of `cloc-studio` must preserve GPL obligations.

When sharing binaries (`.app`, `.zip`), make sure to:

- Include copyright and license notices for upstream `cloc`.
- Provide corresponding source code for the redistributed version (including your modifications).
- Keep recipients informed that `cloc` is GPL-licensed and where source can be obtained.

Before public release, review the upstream `LICENSE` and notices in the `cloc` script header.

This repository includes:
- `LICENSE` (GPL text from upstream)
- `NOTICE` (upstream attribution and bundled-component notice)

## Features
- Multi-select files/folders and drag-and-drop input.
- Visual summary and language breakdown for `cloc --json` results.
- UI-based filters (include/exclude language/ext, max file size, etc.).
- Standalone packaging with bundled `vendor/cloc`.

## Local development
```bash
cd macos-gui
swift build
swift run ClocGUI
```

## Package app
```bash
cd macos-gui
./scripts/package_app.sh
```

Output:
- `dist/ClocGUI.app`
- `dist/ClocGUI.zip`

## Notarized release (optional)
```bash
cd macos-gui
APP_SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
NOTARIZE=1 \
NOTARY_PROFILE="your-notary-profile" \
./scripts/package_app.sh
```
