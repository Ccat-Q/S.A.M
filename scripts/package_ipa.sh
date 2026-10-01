#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts
PACKAGE_DIR=$(mktemp -d)
trap 'rm -rf "$PACKAGE_DIR"' EXIT
mkdir "$PACKAGE_DIR/Payload"
test -d client/build/ios/iphoneos/Runner.app
cp -R client/build/ios/iphoneos/Runner.app "$PACKAGE_DIR/Payload/SAM.app"
test -f "$PACKAGE_DIR/Payload/SAM.app/Runner"
xcrun lipo "$PACKAGE_DIR/Payload/SAM.app/Runner" -verify_arch arm64
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PACKAGE_DIR/Payload/SAM.app/Info.plist"
/usr/libexec/PlistBuddy -c 'Print MinimumOSVersion' "$PACKAGE_DIR/Payload/SAM.app/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print MinimumOSVersion' "$PACKAGE_DIR/Payload/SAM.app/Info.plist")" = '16.0'
# --no-codesign also covers bundled frameworks. Never strip or fabricate signatures.
if codesign --verify --deep --strict "$PACKAGE_DIR/Payload/SAM.app" 2>/dev/null; then
  echo 'Unexpected signed application; unsigned artifact contract violated' >&2
  exit 1
fi
DESTINATION="$PWD/artifacts/sam-unsigned.ipa"
(cd "$PACKAGE_DIR" && zip -qry "$DESTINATION" Payload)
unzip -t "$DESTINATION"
unzip -l "$DESTINATION" > artifacts/IPA-CONTENTS.txt
(cd artifacts && shasum -a 256 sam-unsigned.ipa > IPA-SHA256.txt)
