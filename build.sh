#!/bin/zsh

set -e

rm -rf BlackScreen.app BlackScreen icon.iconset icon.icns

swiftc blackscreen.swift -o BlackScreen

mkdir -p BlackScreen.app/Contents/MacOS
mkdir -p BlackScreen.app/Contents/Resources

mv BlackScreen BlackScreen.app/Contents/MacOS/

if [ -f icon.png ]; then
    mkdir icon.iconset

    sips -z 16 16 icon.png --out icon.iconset/icon_16x16.png
    sips -z 32 32 icon.png --out icon.iconset/icon_16x16@2x.png
    sips -z 32 32 icon.png --out icon.iconset/icon_32x32.png
    sips -z 64 64 icon.png --out icon.iconset/icon_32x32@2x.png
    sips -z 128 128 icon.png --out icon.iconset/icon_128x128.png
    sips -z 256 256 icon.png --out icon.iconset/icon_128x128@2x.png
    sips -z 256 256 icon.png --out icon.iconset/icon_256x256.png
    sips -z 512 512 icon.png --out icon.iconset/icon_256x256@2x.png
    sips -z 512 512 icon.png --out icon.iconset/icon_512x512.png
    cp icon.png icon.iconset/icon_512x512@2x.png

    iconutil -c icns icon.iconset
    mv icon.icns BlackScreen.app/Contents/Resources/icon.icns
fi

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
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

chmod +x BlackScreen.app/Contents/MacOS/BlackScreen

echo "✅ Built BlackScreen.app"
