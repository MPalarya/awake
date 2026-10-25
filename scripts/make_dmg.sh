#!/usr/bin/env bash
# Packages build/Awake.app into build/Awake.dmg (drag-to-Applications layout).
# Run scripts/build_app.sh first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Awake.app"
DMG="$ROOT/build/Awake.dmg"
STAGING="$ROOT/build/dmg-staging"

[[ -d "$APP" ]] || { echo "error: $APP not found; run scripts/build_app.sh first" >&2; exit 1; }

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Awake" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG"

rm -rf "$STAGING"
echo "==> Done: $DMG"
