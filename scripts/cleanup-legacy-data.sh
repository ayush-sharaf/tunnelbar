#!/bin/bash
# Remove data left behind by the app's former name ("TunnelManager").
# Tunnelnest stores its data under ~/Library/Application Support/Tunnelnest;
# this deletes the old ~/Library/Application Support/TunnelManager folder.
#
# Usage:
#   ./scripts/cleanup-legacy-data.sh        # prompts before deleting
#   ./scripts/cleanup-legacy-data.sh -y     # delete without prompting
set -euo pipefail

LEGACY="${HOME}/Library/Application Support/TunnelManager"

if [ ! -d "${LEGACY}" ]; then
  echo "Nothing to clean — '${LEGACY}' does not exist."
  exit 0
fi

echo "Found legacy data directory:"
echo "  ${LEGACY}"
du -sh "${LEGACY}" 2>/dev/null || true

if [ "${1:-}" != "-y" ]; then
  printf "Delete it? [y/N] "
  read -r reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

rm -rf "${LEGACY}"
echo "Deleted ${LEGACY}"
