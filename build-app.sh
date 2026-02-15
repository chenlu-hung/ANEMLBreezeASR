#!/bin/bash

# ANEMLBreezeASR Build Script - Build standalone macOS app
# This script compiles ANEMLBreezeASR and creates a .app bundle

set -e  # Exit on error

echo "🚀 Building ANEMLBreezeASR macOS App..."
echo ""

# Build in release mode
echo "📦 Step 1: Building release binary..."
swift build -c release

# Get the binary path
BINARY_PATH=".build/release/ANEMLBreezeASR"

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Error: Binary not found at $BINARY_PATH"
    exit 1
fi

echo "✅ Binary built successfully"
echo ""

# Create app bundle structure
echo "📁 Step 2: Creating app bundle structure..."
APP_NAME="ANEMLBreezeASR.app"
APP_PATH="build/$APP_NAME"

# Remove old build if exists
rm -rf build
mkdir -p build

# Create bundle directories
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

echo "✅ App bundle structure created"
echo ""

# Copy binary
echo "📄 Step 3: Copying binary..."
cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/ANEMLBreezeASR"
chmod +x "$APP_PATH/Contents/MacOS/ANEMLBreezeASR"

echo "✅ Binary copied"
echo ""

# Create Info.plist
echo "📝 Step 4: Creating Info.plist..."
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_TW</string>
    <key>CFBundleExecutable</key>
    <string>ANEMLBreezeASR</string>
    <key>CFBundleIdentifier</key>
    <string>com.aneml.breezeASR</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ANEMLBreezeASR</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

echo "✅ Info.plist created"
echo ""

# Create PkgInfo
echo "📝 Step 5: Creating PkgInfo..."
echo -n "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo "✅ PkgInfo created"
echo ""

# Sign the app (ad-hoc signature for local use)
echo "🔐 Step 6: Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_PATH"

echo "✅ App signed"
echo ""

echo "🎉 Build complete!"
echo ""
echo "📍 App location: $APP_PATH"
echo ""
echo "To run the app:"
echo "  open build/$APP_NAME"
echo ""
echo "To install to Applications folder:"
echo "  cp -r build/$APP_NAME /Applications/"
echo ""
