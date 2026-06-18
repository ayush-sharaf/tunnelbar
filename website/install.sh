#!/bin/bash
# Tunnelnest installer.
#   curl -fsSL https://<your-domain>/install.sh | bash
#
# Downloads the latest release DMG, installs Tunnelnest.app into /Applications,
# removes the Gatekeeper quarantine flag (the app is not notarized), and launches
# it. No Apple Developer account required.
set -euo pipefail

REPO="ayush-sharaf/tunnelnest"
APP="Tunnelnest.app"
APPS_DIR="/Applications"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
info() { printf "  %s\n" "$1"; }

bold "Installing Tunnelnest…"

# macOS only.
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Tunnelnest is a macOS app; this installer only runs on macOS." >&2
  exit 1
fi

# 1. Find the latest release DMG.
info "Finding the latest release…"
API="https://api.github.com/repos/${REPO}/releases/latest"
DMG_URL=$(curl -fsSL "$API" \
  | grep -o '"browser_download_url"[^,]*\.dmg"' \
  | head -1 \
  | sed -E 's/.*"(https:[^"]+)"$/\1/')

if [ -z "${DMG_URL:-}" ]; then
  echo "Couldn't find a .dmg in the latest release of ${REPO}." >&2
  exit 1
fi

# 2. Download it.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DMG="$TMP/Tunnelnest.dmg"
info "Downloading $(basename "$DMG_URL")…"
curl -fsSL "$DMG_URL" -o "$DMG"

# 3. Mount, copy into /Applications, unmount.
info "Installing to ${APPS_DIR}…"
MOUNT="$(hdiutil attach "$DMG" -nobrowse -readonly | grep -o '/Volumes/.*' | head -1)"
if [ -z "${MOUNT:-}" ]; then
  echo "Failed to mount the disk image." >&2
  exit 1
fi

COPY() { cp -R "$MOUNT/$APP" "$APPS_DIR/"; }
rm -rf "${APPS_DIR:?}/$APP" 2>/dev/null || sudo rm -rf "${APPS_DIR:?}/$APP"
if [ -w "$APPS_DIR" ]; then COPY; else info "(needs admin to write to ${APPS_DIR})"; sudo cp -R "$MOUNT/$APP" "$APPS_DIR/"; fi
hdiutil detach "$MOUNT" >/dev/null

# 4. Remove the download quarantine so Gatekeeper doesn't block it.
xattr -dr com.apple.quarantine "$APPS_DIR/$APP" 2>/dev/null || true

# 5. Launch.
open "$APPS_DIR/$APP"

bold "✅ Tunnelnest is installed in your Applications folder and running in the menu bar."
info "Look for the menu-bar icon (top-right). Add a connection to get started."
