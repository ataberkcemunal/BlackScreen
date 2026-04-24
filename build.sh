#!/bin/zsh

set -e

rm -rf BlackScreen.app BlackScreen icon.iconset icon.icns

echo "🔨 Compiling..."
swiftc blackscreen.swift -o BlackScreen

echo "📦 Creating app bundle..."
mkdir -p BlackScreen.app/Contents/MacOS
mkdir -p BlackScreen.app/Contents/Resources

mv BlackScreen BlackScreen.app/Contents/MacOS/

echo "🧠 Creating Info.plist..."
cat > BlackScreen.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>BlackScreen</string>
    <key>CFBundleDisplayName</key>
    <string>BlackScreen</string>
    <key>CFBundleExecutable</key>
    <string>BlackScreen</string>
    <key>CFBundleIdentifier</key>
    <string>com.ataberk.blackscreen</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x BlackScreen.app/Contents/MacOS/BlackScreen

echo "✅ Done: BlackScreen.app"
