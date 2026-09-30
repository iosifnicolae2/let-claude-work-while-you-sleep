#!/bin/sh
# Builds LetClaudeWork.app into ./build. Run: ./build.sh && open build/LetClaudeWork.app
set -e
cd "$(dirname "$0")"

APP=build/LetClaudeWork.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Universal binary (Apple Silicon + Intel), runs on macOS 13+.
for ARCH in arm64 x86_64; do
    swiftc -O -target $ARCH-apple-macos13 *.swift -o build/LetClaudeWork-$ARCH
done
lipo -create build/LetClaudeWork-* -output "$APP/Contents/MacOS/LetClaudeWork"
rm build/LetClaudeWork-*

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Let Claude Work</string>
    <key>CFBundleIdentifier</key><string>io.bringes.letclaudework</string>
    <key>CFBundleExecutable</key><string>LetClaudeWork</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION:-1.0.0}</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Developer ID (Bringes team) when this Mac has it, needed for notarization. Otherwise ad-hoc, fine for local use.
IDENTITY=$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: .*(CKFK7S3569)"' | head -1 | tr -d '"')
if [ -n "$IDENTITY" ]; then
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi

echo "Built $APP"
