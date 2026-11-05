#!/bin/zsh

set -euo pipefail

# Always run from the project directory, regardless of where it's invoked from.
cd "${0:A:h}"

APP_NAME="BlackScreen"
BUNDLE_ID="com.ataberk.blackscreen"
VERSION="1.0"
DEPLOYMENT_TARGET="13.0"
ARCHS=(arm64 x86_64)

BUILD_DIR="build"
APP="$APP_NAME.app"

rm -rf "$APP" "$APP_NAME" "$BUILD_DIR" icon.iconset icon.icns
mkdir -p "$BUILD_DIR"

echo "🔨 Compiling Swift (${ARCHS[*]})..."
slices=()
for arch in "${ARCHS[@]}"; do
    swiftc -O \
        -target "$arch-apple-macos$DEPLOYMENT_TARGET" \
        blackscreen.swift \
        -o "$BUILD_DIR/$APP_NAME-$arch"
    slices+=("$BUILD_DIR/$APP_NAME-$arch")
done
lipo -create "${slices[@]}" -output "$BUILD_DIR/$APP_NAME"

echo "📦 Creating app bundle..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

echo "🎨 Creating app icon..."
if [[ -f assets/icon.png ]]; then
    mkdir icon.iconset
    for size in 16 32 128 256 512; do
        sips -z $size $size assets/icon.png --out "icon.iconset/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z $double $double assets/icon.png --out "icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns icon.iconset -o "$APP/Contents/Resources/icon.icns"
    rm -rf icon.iconset
else
    echo "⚠️ assets/icon.png not found. App will use default icon."
fi

echo "🧠 Creating Info.plist..."
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>LSMinimumSystemVersion</key>
    <string>$DEPLOYMENT_TARGET</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "🔏 Signing (ad-hoc)..."
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

rm -rf "$BUILD_DIR"
touch "$APP"

echo "✅ Built $APP"
