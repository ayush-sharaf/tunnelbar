#!/bin/bash
# Build TunnelManager.app and package it into a distributable DMG (and zip)
# for sharing with teammates.
#
# The app is only ad-hoc signed (no Apple Developer account), so when a
# teammate downloads it macOS Gatekeeper will quarantine it. See INSTALL.md /
# the printed instructions for the one-time unlock command.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TunnelManager"
BUNDLE="${APP_NAME}.app"
VOL_NAME="Tunnel Manager"
DIST="dist"

# Pull the version from Info.plist for nicely named artifacts.
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0")
DMG="${DIST}/${APP_NAME}-${VERSION}.dmg"
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"

# 1. Build the app.
./build.sh

# 2. Stage a folder with the app + an /Applications symlink for drag-install.
echo "==> Packaging…"
mkdir -p "${DIST}"
rm -f "${DMG}" "${ZIP}"
STAGING=$(mktemp -d)
trap 'rm -rf "${STAGING}"' EXIT
cp -R "${BUNDLE}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

# 3. Build a compressed DMG.
hdiutil create \
  -volname "${VOL_NAME}" \
  -srcfolder "${STAGING}" \
  -ov -format UDZO \
  "${DMG}" >/dev/null
echo "==> Built ${DMG}"

# 4. Also produce a zip (handy for Slack / email).
ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"
echo "==> Built ${ZIP}"

cat <<EOF

Share either artifact with your team:
  • ${DMG}
  • ${ZIP}

IMPORTANT — tell teammates to run this ONCE after copying the app to
/Applications (clears the Gatekeeper quarantine flag):

  xattr -dr com.apple.quarantine /Applications/${BUNDLE}

Then the app opens normally. Full steps are in INSTALL.md.
EOF
