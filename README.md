# cloc-studio

English | [中文](README.zh-TW.md)

`cloc-studio` is a macOS desktop app for running and reviewing [`cloc`](https://github.com/AlDanial/cloc) code-count reports.

<img src="assets/AppIcon-1024.png" alt="cloc-studio icon" width="160" />

It provides a visual workflow for selecting source files or folders, applying common `cloc` filters, and copying the results in formats that are easy to paste into notes, documents, or reports. Standalone app builds bundle `vendor/cloc`, so the packaged `.app` can run without requiring users to install `cloc` separately.

## Screenshots

### Overview

![cloc-studio overview](docs/images/overview-main.png)

### Results

![cloc-studio execution result](docs/images/execution-result.png)

## Features

- Select multiple files or folders with a picker or drag and drop.
- Run `cloc --json` from a native SwiftUI macOS interface.
- Filter by language, extension, directory, maximum file size, git scope, and uniqueness checks.
- Switch between language-level and file-level breakdowns.
- Optionally extract archives before counting, including nested archives such as a `.zip` inside another `.zip`.
- Review summary totals for files, code, comments, blanks, and elapsed time.
- Copy breakdowns as plain text, Markdown, TSV, or HTML table content suitable for Word.
- Build a standalone `.app` with the bundled `vendor/cloc` executable.

Supported archive extraction formats include `.zip`, `.tar`, `.tgz`, `.tar.gz`, `.tbz`, `.tbz2`, `.tar.bz2`, `.txz`, and `.tar.xz`.

## Requirements

- macOS 13 or later.
- Xcode command line tools or Xcode with Swift 6.1-compatible tooling.

## Usage

1. Open `cloc-studio`.
2. Select or drop one or more files, folders, or supported archive files.
3. Configure filters if needed.
4. Enable **Auto extract archives** if selected archives should be expanded before counting.
5. Click **Run cloc**.
6. Copy the resulting table or summary in the format you need.

When archive extraction is enabled, archives are extracted into a temporary directory before `cloc` runs. Temporary extraction folders are removed after the run completes or fails.

## Local Development

```bash
swift build
swift run cloc-studio
```

For development only, you can point the app at a local `cloc` executable:

```bash
CLOC_STUDIO_LOCAL_CLOC=/absolute/path/to/cloc swift run cloc-studio
```

Run tests with:

```bash
swift test
```

## Package App

```bash
./scripts/package_app.sh
```

The packaging script:

- Builds the release binary.
- Generates the app icon assets.
- Verifies `vendor/cloc` against `vendor/cloc.sha256`.
- Bundles `vendor/cloc` into `Contents/Resources/cloc`.
- Signs the app with an ad-hoc identity by default.
- Creates `dist/cloc-studio.app` and `dist/cloc-studio.zip`.

You can override the bundle version with:

```bash
VERSION=0.1.0 ./scripts/package_app.sh
```

## If macOS Blocks Opening the App

If Gatekeeper blocks a downloaded build, remove quarantine attributes only after verifying that the app came from a trusted source:

```bash
xattr -d com.apple.quarantine /path/to/cloc-studio.app
```

If needed for nested files:

```bash
xattr -dr com.apple.quarantine /path/to/cloc-studio.app
```

## Attribution

`cloc-studio` is a GUI wrapper around **cloc** by Al Danial and contributors. It does not replace `cloc`; it provides a macOS interface on top of the upstream counting engine and language logic.

- Upstream project: https://github.com/AlDanial/cloc
- Upstream tool name: `cloc` (Count Lines of Code)
- Bundled runtime in this repo: `vendor/cloc`

Please keep this attribution when redistributing `cloc-studio`.

## License and Compliance

`cloc` is distributed under GNU GPL (v2 or later, per upstream notices). Because this app bundles and redistributes `cloc`, releases of `cloc-studio` must preserve GPL obligations.

When sharing binaries (`.app`, `.zip`), make sure to:

- Include copyright and license notices for upstream `cloc`.
- Provide corresponding source code for the redistributed version, including any modifications.
- Keep recipients informed that `cloc` is GPL-licensed and where source can be obtained.

Before public release, review the upstream `LICENSE` and notices in the `cloc` script header.

This repository includes:

- `LICENSE` (GPL text from upstream)
- `NOTICE` (upstream attribution and bundled-component notice)
