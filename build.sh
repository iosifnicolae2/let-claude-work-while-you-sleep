#!/bin/sh
# Builds LetClaudeWork.app into ./build. Run: ./build.sh && open build/LetClaudeWork.app
set -e
cd "$(dirname "$0")"

APP=build/LetClaudeWork.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O main.swift -o "$APP/Contents/MacOS/LetClaudeWork"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Let Claude Work</string>
    <key>CFBundleIdentifier</key><string>io.bringes.letclaudework</string>
    <key>CFBundleExecutable</key><string>LetClaudeWork</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS accepts it as a login item.
codesign --force --sign - "$APP"

echo "Built $APP"
