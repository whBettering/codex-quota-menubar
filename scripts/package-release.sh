#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexQuotaMenubar"
VERSION="${VERSION:-${GITHUB_REF_NAME:-0.1.0}}"
VERSION="${VERSION#v}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
RELEASE_DIR="$DIST_DIR/release"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
NOTES_PATH="$RELEASE_DIR/release-notes.md"

cd "$ROOT_DIR"

CONFIGURATION=release "$ROOT_DIR/scripts/build-app.sh" >/dev/null

rm -rf "$RELEASE_DIR" "$STAGING_DIR"
mkdir -p "$RELEASE_DIR" "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

cat > "$NOTES_PATH" <<NOTES
# $APP_NAME $VERSION

Download the DMG, open it, and drag $APP_NAME.app to Applications.

This build is unsigned. On first launch, macOS may require right-clicking the app and choosing Open.
NOTES

echo "$DMG_PATH"
