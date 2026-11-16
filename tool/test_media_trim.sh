#!/bin/bash
# 宿主收到测试结果后才退出本次测试进程，避免提前关窗丢失结果。
set -uo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
lease_file="$(mktemp /tmp/echo-loop-trim-log.XXXXXX)"
cleanup() {
  test_pid="$(sed -n 's/.*MEDIA_TRIM_TEST_PID=\([0-9][0-9]*\).*/\1/p' "$lease_file" | head -1)"
  case "$test_pid" in
    ''|*[!0-9]*) ;;
    *)
      test_command="$(ps -p "$test_pid" -o command= 2>/dev/null || true)"
      case "$test_command" in
        "$project_dir"/build/macos/Build/Products/*/Echo\ Loop.app/Contents/MacOS/Echo\ Loop*)
          kill -TERM "$test_pid" 2>/dev/null || true
          for attempt in 1 2 3 4 5 6 7 8 9 10; do
            if ! kill -0 "$test_pid" 2>/dev/null; then break; fi
            sleep 0.1
          done
          if kill -0 "$test_pid" 2>/dev/null; then
            kill -KILL "$test_pid" 2>/dev/null || true
          fi
          ;;
      esac
      ;;
  esac
  rm -f "$lease_file"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cd "$project_dir"
flutter test integration_test/media_trim_integration_test.dart "$@" 2>&1 | tee "$lease_file"
