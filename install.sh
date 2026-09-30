#!/bin/sh
# Builds the app, copies it to /Applications and starts it. Run: ./install.sh
set -e
cd "$(dirname "$0")"

./build.sh
pkill -x LetClaudeWork || true
rm -rf /Applications/LetClaudeWork.app
cp -R build/LetClaudeWork.app /Applications/
open /Applications/LetClaudeWork.app

echo "Installed. Look for the moon in your menu bar."
