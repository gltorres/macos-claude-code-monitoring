#!/usr/bin/env bash
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
