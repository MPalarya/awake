#!/usr/bin/env bash
# Installs the latest Awake release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/MPalarya/Awake/main/install.sh | bash
set -euo pipefail

URL="https://github.com/MPalarya/Awake/releases/latest/download/Awake.dmg"
DEST="/Applications/Awake.app"

[[ "$(uname -m)" == "arm64" ]] || { echo "error: Awake requires an Apple Silicon Mac" >&2; exit 1; }
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ]] || { echo "error: Awake requires macOS 15 or later" >&2; exit 1; }

TMP="$(mktemp -d)"
MOUNT="$TMP/mnt"
cleanup() {
    hdiutil detach -quiet "$MOUNT" 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "==> Downloading Awake"
curl -fL --progress-bar "$URL" -o "$TMP/Awake.dmg"

echo "==> Installing to $DEST"
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$TMP/Awake.dmg"
pkill -x Awake 2>/dev/null || true

SUDO=""
[[ -w /Applications ]] || SUDO="sudo"
$SUDO rm -rf "$DEST"
$SUDO ditto "$MOUNT/Awake.app" "$DEST"
$SUDO xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Launching Awake (look for the cup icon in the menu bar)"
open "$DEST"
