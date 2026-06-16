#!/bin/bash
# Build TunnelManager.app from the Swift sources.
# Uses swiftc directly because SwiftPM's manifest API is broken in bare
# Command Line Tools installs (no full Xcode).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TunnelManager"
BUNDLE="${APP_NAME}.app"
TARGET="arm64-apple-macosx14.0"

echo "==> Compiling ${APP_NAME}…"
mkdir -p build
swiftc -O \
  -target "${TARGET}" \
  -framework AppKit -framework SwiftUI -framework Combine \
  Sources/TunnelManager/*.swift \
  -o "build/${APP_NAME}"

echo "==> Assembling ${BUNDLE}…"
rm -rf "${BUNDLE}"
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"
cp "build/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

# Ad-hoc code signature so macOS will run it locally.
codesign --force --deep --sign - "${BUNDLE}" 2>/dev/null || true

echo "==> Built ${BUNDLE}"
