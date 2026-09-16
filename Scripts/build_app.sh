#!/bin/bash
# Builds the LectureRecorderApp executable with SwiftPM and assembles it into a
# minimal .app bundle, since this project has no Xcode project to build one for us.
# Usage: Scripts/build_app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXECUTABLE_NAME="LectureRecorderApp"
APP_DISPLAY_NAME="Tephra"
BUILD_DIR="$ROOT_DIR/.build/$CONFIG"
APP_BUNDLE="$ROOT_DIR/.build/$APP_DISPLAY_NAME.app"

echo "Building $EXECUTABLE_NAME ($CONFIG)..."
swift build --package-path "$ROOT_DIR" -c "$CONFIG" --product "$EXECUTABLE_NAME"

echo "Assembling app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Ad-hoc signing..."
codesign --force --deep --sign - \
    --entitlements "$ROOT_DIR/Resources/LectureRecorderApp.entitlements" \
    "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
