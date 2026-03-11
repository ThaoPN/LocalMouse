#!/bin/bash
set -e

REPO="ThaoPN/LocalMouse"
APP_NAME="LocalMouse"
INSTALL_DIR="/Applications"

echo "Installing $APP_NAME..."

# Get latest release download URL
LATEST_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" \
  | grep "browser_download_url.*\.dmg" \
  | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
  echo "Error: Could not find latest release DMG."
  exit 1
fi

echo "Downloading $(basename "$LATEST_URL")..."
TMP_DMG=$(mktemp /tmp/LocalMouse-XXXXXX.dmg)
curl -L --progress-bar "$LATEST_URL" -o "$TMP_DMG"

# Mount DMG
echo "Mounting DMG..."
MOUNT_POINT=$(mktemp -d /tmp/LocalMouse-mount-XXXXXX)
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -quiet -nobrowse

# Copy app
echo "Installing to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

# Cleanup mount
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$TMP_DMG"
rmdir "$MOUNT_POINT"

# Remove quarantine and re-sign locally
echo "Signing app..."
/usr/bin/xattr -rd com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
codesign --force --deep --sign - "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "✅ $APP_NAME installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Open LocalMouse from /Applications or Spotlight"
echo "  2. Grant Accessibility permission when prompted"
echo ""
echo "If you previously had LocalMouse in Accessibility list:"
echo "  → System Settings → Privacy & Security → Accessibility"
echo "  → Remove the old LocalMouse entry (select it, click −)"
echo "  → Re-open LocalMouse to add the new entry"
