#!/bin/bash

set -e

echo "🔨 Building LocalMouse..."

# Clean previous builds
rm -rf build
rm -f LocalMouse*.dmg

# Build release (Universal Binary for Intel + Apple Silicon)
xcodebuild -project LocalMouse.xcodeproj \
  -scheme LocalMouse \
  -configuration Release \
  -derivedDataPath ./build \
  ARCHS="x86_64 arm64" \
  ONLY_ACTIVE_ARCH=NO \
  clean build

APP_PATH="./build/Build/Products/Release/LocalMouse.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed - app not found at $APP_PATH"
  exit 1
fi

echo "✅ Build successful"

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
  echo "📦 Installing create-dmg..."
  brew install create-dmg
fi

echo "📀 Creating DMG..."

# Create DMG with drag-and-drop UI
create-dmg \
  --volname "LocalMouse" \
  --window-pos 200 120 \
  --window-size 800 450 \
  --icon-size 100 \
  --icon "LocalMouse.app" 200 190 \
  --hide-extension "LocalMouse.app" \
  --app-drop-link 600 185 \
  --no-internet-enable \
  "LocalMouse.dmg" \
  "$APP_PATH"

echo "✅ DMG created: LocalMouse.dmg"
echo ""
echo "📊 File info:"
ls -lh LocalMouse.dmg
