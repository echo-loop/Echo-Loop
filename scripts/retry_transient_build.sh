#!/usr/bin/env bash

set -uo pipefail

if (($# == 0)); then
  echo "用法: bash scripts/retry_transient_build.sh <构建命令> [参数...]" >&2
  exit 2
fi

readonly max_attempts=3
readonly log_file="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/build-attempt.XXXXXX")"
trap 'rm -f "$log_file"' EXIT

for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  echo "构建尝试 ${attempt}/${max_attempts}"
  : >"$log_file"

  "$@" 2>&1 | tee "$log_file"
  pipeline_status=("${PIPESTATUS[@]}")
  command_status="${pipeline_status[0]}"
  tee_status="${pipeline_status[1]:-0}"

  if ((command_status == 0 && tee_status == 0)); then
    exit 0
  fi

  if ((attempt == max_attempts)) || ! grep -Eiq \
    'HTTP[^[:cntrl:]]*5[0-9]{2}|status code[^[:cntrl:]]*5[0-9]{2}|Gateway Time[- ]out|Bad Gateway|hash of downloaded file.*expected|downloaded file.*(hash|checksum).*(mismatch|expected)|checksum.*mismatch|Gradle threw an error while downloading artifacts from the network|Connection reset by peer|Connection timed out|SocketException.*timed out|TimeoutException' \
    "$log_file"; then
    if ((command_status != 0)); then
      exit "$command_status"
    fi
    exit "$tee_status"
  fi

  delay_seconds=$((attempt * 10))
  echo "::warning::检测到依赖下载或校验的暂时性错误，${delay_seconds} 秒后重试。"
  sleep "$delay_seconds"
done
