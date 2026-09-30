#!/bin/sh
# Builds the app and publishes it as a GitHub release, which brew installs. Run: ./release.sh 1.0.0
set -e
cd "$(dirname "$0")"

VERSION=${1:?usage: ./release.sh <version>}
VERSION=$VERSION ./build.sh
ditto -c -k --keepParent build/LetClaudeWork.app build/LetClaudeWork.zip
gh release create "v$VERSION" build/LetClaudeWork.zip --title "v$VERSION" --notes "brew install --cask iosifnicolae2/tap/let-claude-work"
