#!/bin/bash
set -e

# Script to create a DMG installer for LocalMouse
# Usage: ./scripts/create-dmg.sh [version]

VERSION="${1:-dev}"
APP_NAME="LocalMouse"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"

# Paths
BUILD_DIR="build/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_TEMP="dmg_temp"

echo "Creating DMG for ${APP_NAME} version ${VERSION}..."

# Clean up previous temp directory
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} does not exist. Build the app first."
    exit 1
fi

# Copy app to temp directory
echo "Copying app bundle..."
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create Applications symlink for drag-and-drop installation
echo "Creating Applications symlink..."
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
echo "Creating DMG..."
rm -f "${DMG_NAME}"

hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_NAME}"

# Clean up
rm -rf "${DMG_TEMP}"

echo "✅ Successfully created ${DMG_NAME}"
echo "Size: $(du -h "${DMG_NAME}" | cut -f1)"
