#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 加载公共构建号函数
source scripts/lib/build_number.sh

usage() {
  cat <<'EOF'
Usage: scripts/release_ios.sh [--upload] [--wait] [--work-dir DIR] [--build-name NAME] [--build-number NUMBER]

Build a Flutter iOS IPA and optionally upload it to App Store Connect.

Options:
  --upload        Upload IPA to App Store Connect (default: skip upload).
  --wait          Wait for App Store Connect processing after upload.
  --work-dir      Override the temporary output directory for ExportOptions.plist and logs.
  --build-name    Override CFBundleShortVersionString for this release.
  --build-number  Override CFBundleVersion for this release.
  -h, --help      Show this help.

Environment overrides:
  IOS_TEAM_ID
  IOS_BUILD_NAME
  IOS_BUILD_NUMBER
  APP_STORE_API_KEY_ID
  APP_STORE_API_ISSUER_ID
  APP_STORE_API_KEY_PATH
EOF
}

log() {
  echo "[ios-release] $*"
}

fail() {
  echo "[ios-release] ERROR: $*" >&2
  exit 1
}

ensure_apple_toolchain_path() {
  # Xcode export 会调用带 Apple 扩展参数的 /usr/bin/rsync。
  # 若 PATH 前面命中了 Homebrew rsync，会在打包 IPA 时触发不兼容错误。
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

WAIT_FOR_PROCESSING=0
SKIP_UPLOAD=1
WORK_DIR=""
BUILD_NAME="${IOS_BUILD_NAME:-}"
BUILD_NUMBER="${IOS_BUILD_NUMBER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      SKIP_UPLOAD=0
      ;;
    --wait)
      WAIT_FOR_PROCESSING=1
      ;;
    --work-dir)
      shift
      [[ $# -gt 0 ]] || fail "--work-dir requires a value"
      WORK_DIR="$1"
      ;;
    --build-name)
      shift
      [[ $# -gt 0 ]] || fail "--build-name requires a value"
      BUILD_NAME="$1"
      ;;
    --build-number)
      shift
      [[ $# -gt 0 ]] || fail "--build-number requires a value"
      BUILD_NUMBER="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

require_command flutter
require_command xcrun
require_command plutil
require_command security
ensure_apple_toolchain_path

if [[ -x "scripts/preflight.sh" ]]; then
  scripts/preflight.sh
fi

TEAM_ID="${IOS_TEAM_ID:-S8S968QAV3}"
# Supabase、Google 等编译期变量从 .prod.env 读取；全球/中国 API 可用 API_BASE_URL 和 API_CHINA_BASE_URL 覆盖。
ENV_FILE=".prod.env"
API_KEY_ID="${APP_STORE_API_KEY_ID:-5GB5KL75VZ}"
API_ISSUER_ID="${APP_STORE_API_ISSUER_ID:-3ec439fe-b66c-4034-b8c2-16e133fc4d6b}"
API_KEY_PATH="${APP_STORE_API_KEY_PATH:-$ROOT_DIR/ios/AuthKey_${API_KEY_ID}.p8}"

[[ -f "$API_KEY_PATH" ]] || fail "API key file not found: $API_KEY_PATH"

VERSION_LINE="$(grep -n '^version:' pubspec.yaml || true)"
if [[ -n "$VERSION_LINE" ]]; then
  log "pubspec version: ${VERSION_LINE#*:}"
fi

# 版本名来源优先级：命令行参数 > 环境变量 > pubspec.yaml
if [[ -z "$BUILD_NAME" ]]; then
  BUILD_NAME="${IOS_BUILD_NAME:-}"
fi
if [[ -z "$BUILD_NAME" ]]; then
  BUILD_NAME="$(get_build_name)" || fail "Failed to read version from pubspec.yaml"
  log "BUILD_NAME from pubspec.yaml: $BUILD_NAME"
fi

# 构建号来源优先级：命令行参数 > 环境变量 > commit count（与 GitHub Actions 一致）
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="${IOS_BUILD_NUMBER:-}"
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(git rev-list --count HEAD)"
  log "BUILD_NUMBER from commit count: $BUILD_NUMBER"
fi

log "Using build name: $BUILD_NAME"
log "Using build number: ${BUILD_NUMBER:-1}"
log "Using env file: $ENV_FILE"

log "Checking available code signing identities"
security find-identity -v -p codesigning

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="/tmp/fluency-ios-release-$(date '+%Y%m%d-%H%M%S')"
fi

EXPORT_OPTIONS_PATH="$WORK_DIR/ExportOptions.plist"
UPLOAD_LOG="$WORK_DIR/upload.log"

mkdir -p "$WORK_DIR"

cat > "$EXPORT_OPTIONS_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

plutil -lint "$EXPORT_OPTIONS_PATH"

# xcodebuild 自动在 ~/.appstoreconnect/private_keys/ 查找 API key，
# 将 key 复制到标准位置，确保 flutter build ipa 内部的 xcodebuild 能找到它。
APPLE_KEY_DIR="$HOME/.appstoreconnect/private_keys"
APPLE_KEY_DEST="$APPLE_KEY_DIR/AuthKey_${API_KEY_ID}.p8"
KEY_COPIED=0
if [[ ! -f "$APPLE_KEY_DEST" ]]; then
  mkdir -p "$APPLE_KEY_DIR"
  cp "$API_KEY_PATH" "$APPLE_KEY_DEST"
  KEY_COPIED=1
fi

cleanup_key() {
  if [[ $KEY_COPIED -eq 1 && -f "$APPLE_KEY_DEST" ]]; then
    rm -f "$APPLE_KEY_DEST"
  fi
}
trap cleanup_key EXIT

log "Building Flutter iOS IPA"
[[ -f "$ENV_FILE" ]] || fail "$ENV_FILE not found. Copy .dev.env.template to $ENV_FILE and fill in values."
FLUTTER_BUILD_ARGS=(
  build ipa
  "--release"
  "--flavor=prod"
  "--build-name=$BUILD_NAME"
  "--export-options-plist=$EXPORT_OPTIONS_PATH"
  "--dart-define-from-file=$ENV_FILE"
)
# 仅当有构建号时才传 --build-number
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  FLUTTER_BUILD_ARGS+=("--build-number=$BUILD_NUMBER")
fi
flutter "${FLUTTER_BUILD_ARGS[@]}"

# flutter build ipa 将 IPA 输出到 build/ios/ipa/
IPA_PATH="$(find "$ROOT_DIR/build/ios/ipa" -maxdepth 1 -name '*.ipa' | head -n 1)"
[[ -n "$IPA_PATH" ]] || fail "flutter build ipa succeeded but no IPA found in build/ios/ipa/"

log "IPA ready: $IPA_PATH"
log "Artifacts kept in: $WORK_DIR"

# 复制到统一输出目录
RELEASE_DIR="$ROOT_DIR/build/release"
# 安装包名字统一包含构建号
IPA_VERSION="${BUILD_NAME}+${BUILD_NUMBER}"
IPA_NAME="Echo-Loop-${IPA_VERSION}-ios.ipa"
mkdir -p "$RELEASE_DIR"
cp "$IPA_PATH" "$RELEASE_DIR/$IPA_NAME"
log "Copied to: build/release/$IPA_NAME"

if [[ $SKIP_UPLOAD -eq 1 ]]; then
  log "IPA ready (upload skipped). Use --upload to upload to App Store Connect."
  exit 0
fi

log "Uploading IPA to App Store Connect"
set +e
xcrun altool \
  --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER_ID" \
  --p8-file-path "$API_KEY_PATH" \
  --show-progress \
  2>&1 | tee "$UPLOAD_LOG"
upload_status=${PIPESTATUS[0]}
set -e

delivery_id="$(grep -Eo 'Delivery UUID: [0-9a-fA-F-]+' "$UPLOAD_LOG" | awk '{print $3}' | tail -n 1 || true)"
upload_succeeded=0
if grep -q 'Upload succeeded' "$UPLOAD_LOG"; then
  upload_succeeded=1
fi

if grep -q 'Failed to upload archive' "$UPLOAD_LOG"; then
  upload_succeeded=0
fi

if [[ $upload_status -ne 0 || $upload_succeeded -ne 1 ]]; then
  fail "Upload failed"
fi

if [[ -n "$delivery_id" ]]; then
  log "Delivery UUID: $delivery_id"
else
  log "Upload succeeded, but Delivery UUID was not parsed automatically"
fi

if [[ $WAIT_FOR_PROCESSING -eq 1 ]]; then
  [[ -n "$delivery_id" ]] || fail "Cannot wait for processing without a Delivery UUID"
  log "Waiting for App Store Connect processing"
  xcrun altool \
    --build-status \
    --delivery-id "$delivery_id" \
    --apiKey "$API_KEY_ID" \
    --apiIssuer "$API_ISSUER_ID" \
    --p8-file-path "$API_KEY_PATH" \
    --wait
fi

log "Done"
