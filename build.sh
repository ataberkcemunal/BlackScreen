#!/bin/zsh

set -e

APP_NAME="BlackScreen"
BUNDLE_ID="com.ataberk.blackscreen"

rm -rf "$APP_NAME.app" "$APP_NAME" icon.iconset icon.icns

echo "🔨 Compiling Swift..."
swiftc blackscreen.swift -o "$APP_NAME"

echo "📦 Creating app bundle..."
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

mv "$APP_NAME" "$APP_NAME.app/Contents/MacOS/"

echo "🎨 Creating app icon..."
if [ -f "assets/icon.png" ]; then
    mkdir icon.iconset

    sips -z 16 16 assets/icon.png --out icon.iconset/icon_16x16.png
    sips -z 32 32 assets/icon.png --out icon.iconset/icon_16x16@2x.png
    sips -z 32 32 assets/icon.png --out icon.iconset/icon_32x32.png
    sips -z 64 64 assets/icon.png --out icon.iconset/icon_32x32@2x.png
    sips -z 128 128 assets/icon.png --out icon.iconset/icon_128x128.png
    sips -z 256 256 assets/icon.png --out icon.iconset/icon_128x128@2x.png
    sips -z 256 256 assets/icon.png --out icon.iconset/icon_256x256.png
    sips -z 512 512 assets/icon.png --out icon.iconset/icon_256x256@2x.png
    sips -z 512 512 assets/icon.png --out icon.iconset/icon_512x512.png
    cp assets/icon.png icon.iconset/icon_512x512@2x.png

    iconutil -c icns icon.iconset
    mv icon.icns "$APP_NAME.app/Contents/Resources/icon.icns"
else
    echo "⚠️ assets/icon.png not found. App will use default icon."
fi

echo "🧠 Creating Info.plist..."
cat > "$APP_NAME.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"

xattr -cr "$APP_NAME.app"
touch "$APP_NAME.app"

echo "✅ Built $APP_NAME.app"
