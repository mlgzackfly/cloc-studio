#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClocGUI"
BUNDLE_ID="com.cloc.gui"
VERSION="0.1.0"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
BIN_PATH="$BUILD_DIR/$APP_NAME"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
DIST_DIR="$ROOT_DIR/dist"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"

# Configurable options:
# - APP_SIGN_IDENTITY: codesign identity (default "-" for ad-hoc)
# - NOTARIZE: set to "1" to notarize
# - NOTARY_PROFILE: keychain profile name for xcrun notarytool
# - STAPLE: set to "0" to skip stapling (default "1")
SIGN_IDENTITY="${APP_SIGN_IDENTITY:--}"
NOTARIZE="${NOTARIZE:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
STAPLE="${STAPLE:-1}"

cd "$ROOT_DIR"
swift build -c release
./scripts/build_icon.sh

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Release binary not found: $BIN_PATH" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Bundle vendored cloc executable so macos-gui can be packaged standalone.
if [[ ! -x "$ROOT_DIR/vendor/cloc" ]]; then
  echo "Missing vendored cloc at $ROOT_DIR/vendor/cloc" >&2
  exit 1
fi
cp "$ROOT_DIR/vendor/cloc" "$RES_DIR/cloc"
chmod +x "$RES_DIR/cloc"
cp "$ROOT_DIR/assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if ! command -v codesign >/dev/null 2>&1; then
  echo "codesign not found; cannot sign app bundle." >&2
  exit 1
fi

echo "Signing app with identity: $SIGN_IDENTITY"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi
codesign --verify --deep --strict "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found; cannot notarize." >&2
    exit 1
  fi
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "NOTARY_PROFILE is required when NOTARIZE=1." >&2
    exit 1
  fi
  echo "Submitting for notarization via profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  if [[ "$STAPLE" != "0" ]]; then
    xcrun stapler staple "$APP_DIR"
    xcrun stapler validate "$APP_DIR"
  fi
fi

echo "Packaged app: $APP_DIR"
echo "Shareable zip: $ZIP_PATH"
