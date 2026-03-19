#!/bin/bash
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="PBL Zone"
BUILD_DIR="${PROJECT_DIR}/build"
OUT_DMG="${PROJECT_DIR}/build/PBLZone.dmg"
UNLOCK_SCRIPT="${PROJECT_DIR}/scripts/unlock_quarantine.command"
# Version: pass as first argument (e.g. ./build_dmg.sh 1.0.3), defaults to git tag
APP_VERSION="${1:-}"
if [ -z "$APP_VERSION" ]; then
    LATEST_TAG=$(git -C "$PROJECT_DIR" tag -l 'v*' --sort=-v:refname 2>/dev/null | head -1)
    APP_VERSION="${LATEST_TAG#v}"
    [ -z "$APP_VERSION" ] && APP_VERSION="1.0.0"
fi
echo "📌  Version: ${APP_VERSION}"

# ── Clean previous build ────────────────────────────────────────────────
echo "🧹  Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Build ───────────────────────────────────────────────────────────────
echo "🔨  Building ${SCHEME} (Release)..."
xcodebuild \
  -project "${PROJECT_DIR}/PBL.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  MACOSX_DEPLOYMENT_TARGET=14.6 \
  MARKETING_VERSION="${APP_VERSION}" \
  CURRENT_PROJECT_VERSION="${APP_VERSION}" \
  build \
  2>&1 | tail -5

APP="${BUILD_DIR}/DerivedData/Build/Products/Release/${SCHEME}.app"

if [ ! -d "$APP" ]; then
    echo "❌  Build failed — .app not found."
    exit 1
fi

# ── Ad-hoc sign ─────────────────────────────────────────────────────────
echo "🔏  Signing..."
xattr -cs "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

# ── Stage DMG contents ──────────────────────────────────────────────────
echo "📦  Packaging DMG..."
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$UNLOCK_SCRIPT" "$STAGE/Unlock PBL Zone.command"
chmod +x "$STAGE/Unlock PBL Zone.command"

# ── Create DMG ──────────────────────────────────────────────────────────
hdiutil create \
  -volname "${SCHEME}" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$OUT_DMG"

rm -rf "$STAGE"

echo ""
echo "✅  Done: ${OUT_DMG}"
echo "   Size: $(du -h "$OUT_DMG" | cut -f1)"
