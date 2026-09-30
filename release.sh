#!/bin/sh
# Builds the app and publishes it as a GitHub release, which brew installs. Run: ./release.sh 1.0.0
set -e
cd "$(dirname "$0")"

VERSION=${1:?usage: ./release.sh <version>}
APP=build/LetClaudeWork.app
ZIP=build/LetClaudeWork.zip
VERSION=$VERSION ./build.sh

codesign -dv "$APP" 2>&1 | grep -q "Authority=Developer ID Application" ||
    { echo "Not signed with Developer ID. Create the certificate in Xcode first."; exit 1; }

# Apple scans the app, then the approval is stapled to it so it opens even offline.
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile notary --wait
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"

gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --notes "brew install --cask iosifnicolae2/tap/let-claude-work"
