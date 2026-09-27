#!/bin/zsh
# Builds a Release copy of Advisor OS and packages it as a .dmg in dist/.
# Signed with the local "Advisor OS Local Signing" identity, not notarized by Apple,
# so other Macs show an "unidentified developer" warning the first time (see the note inside the .dmg).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"(.*)".*/\1/')
DERIVED=build/Release
APP="$DERIVED/Build/Products/Release/Advisor OS.app"
STAGE=build/dmg-stage
DMG="dist/AdvisorOS-$VERSION.dmg"

xcodegen generate >/dev/null
xcodebuild -project AdvisorOS.xcodeproj -scheme AdvisorOS -configuration Release -derivedDataPath "$DERIVED" build -quiet
codesign --verify --strict "$APP"

rm -rf "$STAGE" && mkdir -p "$STAGE" dist
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/How to open Advisor OS.txt" <<'TXT'
Advisor OS 
===========

1. Drag "Advisor OS" into the Applications folder.
2. Open it. macOS will say it can't verify the developer, because this copy
   isn't notarized by Apple yet. Click Done.
3. Open System Settings › Privacy & Security, scroll down, and click
   "Open Anyway" next to Advisor OS. Confirm with your password.

You only need to do this once. Everything Advisor OS stores stays on your Mac.
Personal project for educational purposes. Not financial advice.
TXT

rm -f "$DMG"
hdiutil create -volname "Advisor OS" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --sign "Advisor OS Local Signing" "$DMG"
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
