#!/usr/bin/env bash
#
# Maintainer-only release script.
#
# Requires:
#   - An "Apple Developer ID Application" certificate in the login keychain.
#   - An `AC_NOTARY` notarization profile created via:
#       xcrun notarytool store-credentials AC_NOTARY \
#           --apple-id <id> --team-id <team> --password <app-specific-pwd>
#
# Forks and contributors should use the unsigned DMG flow documented in
# README.md ("Build a release DMG") instead — it produces a Mach-O that
# runs locally after `xattr -dr com.apple.quarantine`.
set -euo pipefail

APP="ClaudeMon"
SCHEME="ClaudeMon"
BUILD_DIR=".build"
EXPORT_DIR="$BUILD_DIR/Export"
ARCHIVE="$BUILD_DIR/$APP.xcarchive"
DMG="$BUILD_DIR/$APP.dmg"

xcodebuild -project "$APP.xcodeproj" -scheme "$SCHEME" \
    -configuration Release -archivePath "$ARCHIVE" archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" -exportOptionsPlist scripts/ExportOptions.plist

xcrun notarytool submit "$EXPORT_DIR/$APP.app" \
    --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple "$EXPORT_DIR/$APP.app"

hdiutil create -volname "$APP" -srcfolder "$EXPORT_DIR/$APP.app" -ov -format UDZO "$DMG"
echo "Built $DMG"
