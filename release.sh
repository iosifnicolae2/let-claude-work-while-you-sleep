#!/bin/sh
# Builds the app and publishes it as a GitHub release, which brew installs. Run: ./release.sh 1.0.0
set -e
cd "$(dirname "$0")"

VERSION=${1:?usage: ./release.sh <version>}
APP=build/LetClaudeWork.app
ZIP=build/LetClaudeWork.zip
VERSION=$VERSION ./build.sh

ditto -c -k --keepParent "$APP" "$ZIP"

# Signed with Developer ID: Apple scans it, and the approval is stapled on so it opens even offline.
# Unsigned: still works through brew, which clears the "downloaded from the internet" flag.
if codesign -dv "$APP" 2>&1 | grep -q "Authority=Developer ID Application"; then
    xcrun notarytool submit "$ZIP" --keychain-profile notary --wait
    xcrun stapler staple "$APP"
    ditto -c -k --keepParent "$APP" "$ZIP"
else
    echo "Not signed with Developer ID: publishing without notarization."
fi

gh release create "v$VERSION" "$ZIP" --title "v$VERSION" --notes "brew install --cask iosifnicolae2/tap/let-claude-work"
