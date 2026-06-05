#!/usr/bin/env bash
# Shared helpers for local dev scripts (sourced by start-dev.sh).

die() {
  echo "[错误] $*" >&2
  exit 1
}

cleanup_partial_start() {
  if [ -n "${ROOT:-}" ] && [ -f "$ROOT/scripts/stop-dev.sh" ]; then
    "$ROOT/scripts/stop-dev.sh" 2>/dev/null || true
  fi
}

# Print failure reason, tail log, stop partial stack, exit 1.
fail_and_cleanup() {
  local msg="$1"
  local logfile="${2:-}"
  echo "[错误] $msg" >&2
  if [ -n "$logfile" ] && [ -f "$logfile" ]; then
    echo "日志: $logfile" >&2
    echo "最后 15 行:" >&2
    tail -15 "$logfile" 2>/dev/null | sed 's/^/  /' >&2
  fi
  cleanup_partial_start
  exit 1
}

require_file() {
  local path="$1"
  local hint="$2"
  if [ ! -f "$path" ]; then
    die "$hint"
  fi
}

# Returns mac or linux for scripts/bin subdir; empty if unsupported.
centrifugo_platform_subdir() {
  case "$(uname -s)" in
    Darwin*) echo mac ;;
    Linux*) echo linux ;;
    *) echo "" ;;
  esac
}

centrifugo_linux_bin() {
  echo "$ROOT/scripts/bin/linux/centrifugo"
}

# Returns 0 if the binary runs on this machine (OS/arch), not merely chmod +x.
centrifugo_runnable() {
  local bin="$1"
  [ -f "$bin" ] && [ -x "$bin" ] && "$bin" version >/dev/null 2>&1
}

centrifugo_candidate_paths() {
  local platform
  platform="$(centrifugo_platform_subdir)"
  if [ -n "$platform" ]; then
    printf '%s\n' "$ROOT/scripts/bin/$platform/centrifugo"
  fi
  printf '%s\n' "$ROOT/scripts/bin/centrifugo"
  if command -v centrifugo >/dev/null 2>&1; then
    command -v centrifugo
  fi
}

# Human-readable hint when a file exists but cannot execute (e.g. Linux bin on macOS).
centrifugo_mismatch_hint() {
  local bin="$1"
  if [ ! -f "$bin" ]; then
    return 0
  fi
  if command -v file >/dev/null 2>&1; then
    echo "（$bin: $(file -b "$bin")）"
  fi
}

# Prints absolute path to centrifugo binary, or returns 1.
resolve_centrifugo_bin() {
  local candidate
  while IFS= read -r candidate; do
    [ -z "$candidate" ] && continue
    if centrifugo_runnable "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done <<EOF
$(centrifugo_candidate_paths)
EOF
  return 1
}

centrifugo_resolve_error_msg() {
  local msg="未找到可在本机运行的 Centrifugo。"
  local bad=""
  while IFS= read -r candidate; do
    [ -z "$candidate" ] || [ ! -f "$candidate" ] && continue
    if ! centrifugo_runnable "$candidate"; then
      bad="$candidate"
      break
    fi
  done <<EOF
$(centrifugo_candidate_paths)
EOF
  if [ -n "$bad" ]; then
    msg+=" 检测到 $bad 与当前系统不匹配$(centrifugo_mismatch_hint "$bad")。"
  fi
  local platform_hint="scripts/bin/mac/centrifugo 或 scripts/bin/linux/centrifugo"
  if [ -n "$(centrifugo_platform_subdir)" ]; then
    platform_hint="scripts/bin/$(centrifugo_platform_subdir)/centrifugo"
  fi
  msg+=" 请运行: ./scripts/install-centrifugo.sh（或从 https://github.com/centrifugal/centrifugo/releases 下载对应平台二进制到 $platform_hint）"
  echo "$msg"
}

# wait_service name pid timeout_seconds logfile mode
# mode: port_8000 | port_3000 | backend_refresh
# Returns 0 when ready, 1 on timeout or process exit.
wait_service() {
  local name="$1"
  local pid="$2"
  local timeout="$3"
  local logfile="$4"
  local mode="$5"
  local i ready=0

  printf "等待 %s 就绪" "$name"
  for i in $(seq 1 "$timeout"); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo ""
      return 1
    fi
    case "$mode" in
      port_8000)
        if curl -s -o /dev/null http://localhost:8000/ 2>/dev/null; then
          ready=1
        fi
        ;;
      port_3000)
        if curl -s -o /dev/null http://localhost:3000/ 2>/dev/null; then
          ready=1
        fi
        ;;
      backend_refresh)
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/auth/refresh 2>/dev/null | grep -q '401\|200'; then
          ready=1
        fi
        ;;
      *)
        echo ""
        echo "[错误] wait_service: 未知模式 $mode" >&2
        return 1
        ;;
    esac
    if [ "$ready" -eq 1 ]; then
      echo " OK (PID $pid)"
      return 0
    fi
    printf "."
    sleep 1
  done
  echo ""
  return 1
}

service_fail_reason() {
  local pid="$1"
  local timeout_msg="$2"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "进程已退出（PID $pid）"
  else
    echo "$timeout_msg"
  fi
}
