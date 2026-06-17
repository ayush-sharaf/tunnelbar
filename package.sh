#!/bin/bash
# Build Tunnelbar.app and package it into a distributable DMG (and zip).
#
# The app is only ad-hoc signed (no Apple Developer account), so when a
# teammate downloads it macOS Gatekeeper will quarantine it. See INSTALL.md /
# the printed instructions for the one-time unlock command.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Tunnelbar"
BUNDLE="${APP_NAME}.app"
VOL_NAME="Tunnelbar"
DIST="dist"

# Version is stamped at build time. Releases set TUNNELBAR_VERSION; local
# packaging defaults to a dev version.
VERSION="${TUNNELBAR_VERSION:-0.0.0-dev}"
DMG="${DIST}/${APP_NAME}-${VERSION}.dmg"
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"

# 1. Build the app (build.sh reads TUNNELBAR_VERSION to stamp the bundle).
TUNNELBAR_VERSION="${VERSION}" ./build.sh

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
