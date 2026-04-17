#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  echo "[android-release] $*"
}

fail() {
  echo "[android-release] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/release_android.sh [--flavor <dev|prod>] [--no-upload] [--skip-build] [-h|--help]

Build a release APK and upload it to Cloudflare R2.

Options:
  --flavor <f>  Product flavor: dev or prod (default: prod).
  --no-upload   Skip uploading the APK to R2.
  --skip-build  Skip the build step (use existing APK in build/release/).
  -h, --help    Show this help.

Environment variables:
  API_BASE_URL          API base URL (default: https://www.echo-loop.top)
  POSTHOG_API_KEY       PostHog API key (required for analytics)
  POSTHOG_HOST          PostHog host URL (default: https://us.i.posthog.com)

  R2 upload:
  R2_ENDPOINT           S3-compatible endpoint URL
  R2_ACCESS_KEY_ID      R2 API token access key ID
  R2_SECRET_ACCESS_KEY  R2 API token secret access key
  R2_BUCKET             R2 bucket name (default: public)
  R2_PUBLIC_URL         Public base URL for download links (default: https://cdn.echo-loop.top)
EOF
}

# --- 参数解析 ---
DO_UPLOAD=true
SKIP_BUILD=false
FLAVOR="prod"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flavor)     FLAVOR="${2:-}"; shift 2 ;;
    --no-upload)  DO_UPLOAD=false; shift ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            fail "Unknown option: $1. Use -h for help." ;;
  esac
done

[[ "$FLAVOR" == "dev" || "$FLAVOR" == "prod" ]] || fail "Invalid --flavor: $FLAVOR (expected dev|prod)"

# --- 环境检查 ---
if [[ -z "${ANDROID_HOME:-}" ]]; then
  if [[ -d "$HOME/Android/Sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  elif [[ -d "$HOME/Android/sdk" ]]; then
    export ANDROID_HOME="$HOME/Android/sdk"
  else
    fail "ANDROID_HOME is not set and ~/Android/Sdk does not exist"
  fi
fi
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"

API_BASE_URL="${API_BASE_URL:-https://www.echo-loop.top}"
POSTHOG_API_KEY="${POSTHOG_API_KEY:-}"
POSTHOG_HOST="${POSTHOG_HOST:-https://us.i.posthog.com}"

# 从 pubspec.yaml 读取版本号
RAW_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
[[ -n "$RAW_VERSION" ]] || fail "Unable to read version from pubspec.yaml"

VERSION="${RAW_VERSION%%+*}"
ARCH="arm64"
APK_NAME="Echo-Loop-${VERSION}-${ARCH}.apk"
APK_PATH="build/release/$APK_NAME"

log "Version: $VERSION"
log "Architecture: $ARCH"
log "Flavor: $FLAVOR"
log "API base URL: $API_BASE_URL"
log "Output: $APK_PATH"

# --- 构建 ---
if [[ "$SKIP_BUILD" == false ]]; then
  log "Cleaning..."
  flutter clean

  log "Building release APK..."
  DART_DEFINES=(
    "--dart-define=API_BASE_URL=${API_BASE_URL}"
    "--dart-define=POSTHOG_HOST=${POSTHOG_HOST}"
  )
  # POSTHOG_API_KEY 为空时不传，让代码使用内置默认值
  [[ -n "${POSTHOG_API_KEY:-}" ]] && DART_DEFINES+=("--dart-define=POSTHOG_API_KEY=${POSTHOG_API_KEY}")

  flutter build apk --release \
    --flavor "$FLAVOR" \
    --target-platform android-arm64 \
    "${DART_DEFINES[@]}"

  SRC="build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
  [[ -f "$SRC" ]] || fail "APK not found at $SRC"

  mkdir -p build/release
  cp "$SRC" "$APK_PATH"

  SIZE="$(du -h "$APK_PATH" | cut -f1 | xargs)"
  log "Build done: $APK_PATH ($SIZE)"
else
  log "Skipping build (--skip-build)"
  [[ -f "$APK_PATH" ]] || fail "APK not found at $APK_PATH. Run without --skip-build first."
fi

# --- 上传到 R2 ---
if [[ "$DO_UPLOAD" == true ]]; then
  # 检查必要环境变量
  : "${R2_ENDPOINT:?Set R2_ENDPOINT}"
  R2_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-$R2_ACCESS_KEY_ID_PUBLIC}"
  R2_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-$R2_SECRET_ACCESS_KEY_PUBLIC}"
  : "${R2_ACCESS_KEY_ID:?Set R2_ACCESS_KEY_ID or R2_ACCESS_KEY_ID_PUBLIC}"
  : "${R2_SECRET_ACCESS_KEY:?Set R2_SECRET_ACCESS_KEY or R2_SECRET_ACCESS_KEY_PUBLIC}"
  R2_BUCKET="${R2_BUCKET:-public}"
  R2_PUBLIC_URL="${R2_PUBLIC_URL:-https://cdn.echo-loop.top}"

  command -v aws >/dev/null 2>&1 || fail "aws CLI not found. Install it first."

  R2_KEY="android/$APK_NAME"
  R2_LATEST_KEY="android/Echo-Loop-latest.apk"

  log "Uploading to R2: s3://${R2_BUCKET}/${R2_KEY} ..."

  AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  aws s3 cp "$APK_PATH" "s3://${R2_BUCKET}/${R2_KEY}" \
    --endpoint-url "$R2_ENDPOINT" \
    --region auto \
    --content-type "application/vnd.android.package-archive"

  log "Copying to latest: s3://${R2_BUCKET}/${R2_LATEST_KEY} ..."

  AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  aws s3 cp "$APK_PATH" "s3://${R2_BUCKET}/${R2_LATEST_KEY}" \
    --endpoint-url "$R2_ENDPOINT" \
    --region auto \
    --content-type "application/vnd.android.package-archive"

  DOWNLOAD_URL="${R2_PUBLIC_URL%/}/${R2_LATEST_KEY}"
  log "Upload done!"
  log "Download URL: $DOWNLOAD_URL"
fi

log "All done."
