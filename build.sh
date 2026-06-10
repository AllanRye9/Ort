#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# build.sh  —  Ort Marketplace build helper
#
# Usage:
#   ./build.sh apk          # Android release APK  → build/app/outputs/flutter-apk/
#   ./build.sh ipa          # iOS archive (requires macOS + Xcode)
#   ./build.sh web          # Flutter Web build    → build/web/
#   ./build.sh appbundle    # Android App Bundle   → build/app/outputs/bundle/
#
# Override the API base URL:
#   API_URL=https://piitrade.com/api/v1 ./build.sh apk
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

API_URL="${API_URL:-https://piitrade.com/api/v1}"
DART_DEFINES="--dart-define=API_BASE_URL=${API_URL}"

TARGET="${1:-apk}"

echo "╔══════════════════════════════════════════════════╗"
echo "║   Ort Marketplace — build: ${TARGET}"
echo "║   API_BASE_URL: ${API_URL}"
echo "╚══════════════════════════════════════════════════╝"

# Go to the Flutter project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/ort_marketplace"

# Ensure dependencies are up to date
flutter pub get

case "$TARGET" in
  apk)
    flutter build apk --release ${DART_DEFINES}
    echo ""
    echo "✅  APK built:"
    echo "    $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
    ;;

  appbundle)
    flutter build appbundle --release ${DART_DEFINES}
    echo ""
    echo "✅  App Bundle built:"
    echo "    $(pwd)/build/app/outputs/bundle/release/app-release.aab"
    ;;

  ipa)
    flutter build ios --release --no-codesign ${DART_DEFINES}
    echo ""
    echo "✅  iOS build complete (no-codesign)."
    echo "    Open Xcode to archive and export the IPA:"
    echo "    $(pwd)/ios/Runner.xcworkspace"
    ;;

  web)
    flutter build web --release ${DART_DEFINES} \
      --base-href / \
      --web-renderer canvaskit
    echo ""
    echo "✅  Web build:"
    echo "    $(pwd)/build/web/"
    ;;

  *)
    echo "❌  Unknown target: ${TARGET}"
    echo "    Valid targets: apk | appbundle | ipa | web"
    exit 1
    ;;
esac
