#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(cat VERSION)}"
VERSION="${VERSION#v}"
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
APP="$PWD/dist/Sift.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Sift" "$APP/Contents/MacOS/Sift"
for bundle in "$BIN_DIR"/*.bundle; do
    [ -d "$bundle" ] || continue
    ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
swift Scripts/generate-icon.swift "$PWD/dist/Sift.iconset"
python3 Scripts/package-icon.py "$PWD/dist/Sift.iconset" "$APP/Contents/Resources/Sift.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set CFBundleVersion ${GITHUB_RUN_NUMBER:-1}" "$APP/Contents/Info.plist"
if [ -n "${MICROSOFT_CLIENT_ID:-}" ]; then
    /usr/libexec/PlistBuddy -c "Add SiftMicrosoftClientID string $MICROSOFT_CLIENT_ID" "$APP/Contents/Info.plist"
fi
codesign --force --deep --sign - --entitlements Resources/Sift.entitlements "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/Sift-macOS-arm64.zip
mkdir -p dist/dmg-stage
ditto "$APP" dist/dmg-stage/Sift.app
ln -sfn /Applications dist/dmg-stage/Applications
hdiutil create -volname Sift -srcfolder dist/dmg-stage -ov -format UDZO dist/Sift-macOS-arm64.dmg
shasum -a 256 dist/Sift-macOS-arm64.zip dist/Sift-macOS-arm64.dmg > dist/SHA256SUMS.txt
printf 'Packaged %s\n' "$APP"
