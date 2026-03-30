#!/bin/bash
set -e

# .env 파일 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_SPECIFIC_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
    echo "❌ .env 파일에 APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID 필요"
    exit 1
fi

VERSION=${1:-"1.0.0"}
APP_NAME="Claude Clipboard Cleaner"
BUNDLE_ID="ClaudeClipboardCleaner"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$BUNDLE_ID-$VERSION-arm64.dmg"

# 서명 ID 자동 탐색
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$IDENTITY" ]; then
    echo "❌ Developer ID Application 인증서를 찾을 수 없습니다"
    exit 1
fi
echo "🔑 Signing identity: $IDENTITY"

# 빌드
./build.sh

# 코드서명
echo "🔐 Signing..."
codesign --force --options runtime \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"

codesign -dv --verbose=2 "$APP_BUNDLE" 2>&1 | grep "Authority"

# DMG 생성
echo "📦 Creating DMG..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$DMG_NAME"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# DMG 서명
codesign --force --sign "$IDENTITY" "$DIST_DIR/$DMG_NAME"

# 공증
echo "📤 Notarizing..."
xcrun notarytool submit "$DIST_DIR/$DMG_NAME" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

# 스태플
xcrun stapler staple "$DIST_DIR/$DMG_NAME"

echo ""
echo "✅ Done: $DIST_DIR/$DMG_NAME"
echo "📊 $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
