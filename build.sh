#!/bin/bash
# Build Tunnelnest.app from the Swift sources.
# Uses swiftc directly because SwiftPM's manifest API is broken in bare
# Command Line Tools installs (no full Xcode).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Tunnelnest"
BUNDLE="${APP_NAME}.app"
TARGET="arm64-apple-macosx14.0"
# Version is stamped at build time (the source Info.plist holds a placeholder).
# Local builds default to a dev version; releases set TUNNELNEST_VERSION.
VERSION="${TUNNELNEST_VERSION:-0.0.0-dev}"

echo "==> Compiling ${APP_NAME}…"
mkdir -p build
swiftc -O \
  -target "${TARGET}" \
  -framework AppKit -framework SwiftUI -framework Combine \
  Sources/Tunnelnest/*.swift \
  -o "build/${APP_NAME}"

echo "==> Assembling ${BUNDLE}…"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"
cp "build/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

# Stamp the version into the bundle's Info.plist (not the source).
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "${BUNDLE}/Contents/Info.plist"
echo "==> Stamped version ${VERSION}"

# App icon (generate once with: swift scripts/generate-icon.swift)
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code signature so macOS will run it locally.
codesign --force --deep --sign - "${BUNDLE}" 2>/dev/null || true

echo "==> Built ${BUNDLE}"
