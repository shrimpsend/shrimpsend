#!/usr/bin/env bash
# 启动本地开发环境：Centrifugo、后端、Web
# 用法:
#   ./scripts/start-dev.sh              # 国内逻辑（默认 Spring profile）
#   ./scripts/start-dev.sh --overseas   # 海外 ShrimpSend 逻辑（dev-overseas）
# 停止：./scripts/stop-dev.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/dev-common.sh
source "$ROOT/scripts/lib/dev-common.sh"

cd "$ROOT"
export PATH="$ROOT/scripts/bin:$PATH"
PID_FILE="$ROOT/scripts/.dev-pids"
LOG_DIR="$ROOT/scripts/logs"
mkdir -p "$LOG_DIR"

CFGO_LOG="$LOG_DIR/centrifugo.log"
BACKEND_LOG="$LOG_DIR/backend.log"
WEB_LOG="$LOG_DIR/web.log"

OVERSEAS=false
for arg in "$@"; do
  case "$arg" in
    --overseas) OVERSEAS=true ;;
    *)
      die "未知参数: $arg（支持: --overseas）"
      ;;
  esac
done

if [ -f "$ROOT/backend/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/backend/.env"
  set +a
fi

if [ "$OVERSEAS" = true ] && [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

# 与 config.json 中的 Centrifugo 密钥对齐（setup-local-config 可能已随机化 config.json）
if [ -f "$ROOT/config.json" ] && command -v python3 >/dev/null 2>&1; then
  eval "$(ROOT="$ROOT" python3 - <<'PY'
import json, os
from pathlib import Path
cfg = json.loads(Path(os.environ["ROOT"], "config.json").read_text())
print(f'export CENTRIFUGO_HTTP_API_KEY={cfg["http_api"]["key"]!r}')
print(f'export CENTRIFUGO_TOKEN_HMAC_SECRET={cfg["client"]["token"]["hmac_secret_key"]!r}')
PY
)"
fi

# 若已有进程，先尝试停止
if [ -f "$PID_FILE" ]; then
  echo "发现已有 .dev-pids，先执行 stop-dev.sh"
  "$ROOT/scripts/stop-dev.sh" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

if [ "$OVERSEAS" = true ]; then
  echo "模式: 海外本地 (Spring profile dev-overseas, DB ultrasend_overseas)"
else
  echo "模式: 国内本地 (默认 Spring profile, DB ultrasend)"
fi

echo "==> 启动前检查"
require_file "$ROOT/config.json" \
  "缺少 config.json。请运行: ./scripts/setup-local-config.sh 或 ./scripts/deploy-local.sh"

CFGO_BIN=""
if ! CFGO_BIN="$(resolve_centrifugo_bin)"; then
  die "$(centrifugo_resolve_error_msg)"
fi

if [ ! -x "$ROOT/backend/gradlew" ]; then
  die "backend/gradlew 不可执行。请运行: chmod +x backend/gradlew"
fi

if [ ! -x "$ROOT/web/node_modules/.bin/next" ]; then
  die "未找到 web 依赖（next）。请先执行: cd web && npm ci"
fi

echo "  config.json、Centrifugo、Gradle、Web 依赖: OK"

echo "启动 Centrifugo (config.json)..."
: > "$CFGO_LOG"
"$CFGO_BIN" -c "$ROOT/config.json" >> "$CFGO_LOG" 2>&1 &
pid_c=$!
echo "$pid_c" >> "$PID_FILE"

if ! wait_service "Centrifugo" "$pid_c" 10 "$CFGO_LOG" port_8000; then
  reason="$(service_fail_reason "$pid_c" "端口 8000 在 10 秒内未就绪")"
  fail_and_cleanup "Centrifugo 启动失败：${reason}（请检查 $CFGO_BIN 与 config.json）" "$CFGO_LOG"
fi

echo "启动后端 (Spring Boot)..."
if [ "$OVERSEAS" = true ]; then
  (
    cd "$ROOT/backend"
    export SPRING_PROFILES_ACTIVE=dev-overseas
    exec ./gradlew bootRun
  ) >> "$BACKEND_LOG" 2>&1 &
else
  (cd "$ROOT/backend" && exec ./gradlew bootRun) >> "$BACKEND_LOG" 2>&1 &
fi
pid_b=$!
echo "$pid_b" >> "$PID_FILE"

if ! wait_service "后端 API" "$pid_b" 60 "$BACKEND_LOG" backend_refresh; then
  reason="$(service_fail_reason "$pid_b" "http://localhost:9000 在 60 秒内未就绪")"
  fail_and_cleanup "后端启动失败：${reason}（请检查 MySQL 与 backend/.env）" "$BACKEND_LOG"
fi

echo "启动 Web (Next.js)..."
(cd "$ROOT/web" && exec npm run dev) >> "$WEB_LOG" 2>&1 &
pid_w=$!
echo "$pid_w" >> "$PID_FILE"

if ! wait_service "Web" "$pid_w" 20 "$WEB_LOG" port_3000; then
  reason="$(service_fail_reason "$pid_w" "端口 3000 在 20 秒内未就绪")"
  fail_and_cleanup "Web 启动失败：${reason}（若日志含 next: command not found，请执行 cd web && npm ci）" "$WEB_LOG"
fi

echo ""
echo "本地服务已启动："
echo "  Centrifugo: http://localhost:8000"
echo "  后端 API:  http://localhost:9000"
echo "  Web:       http://localhost:3000"
echo ""
echo "日志: $LOG_DIR/ (centrifugo.log, backend.log, web.log)"
echo "停止: $ROOT/scripts/stop-dev.sh"
if [ "$OVERSEAS" = true ]; then
  echo ""
  echo "Stripe 本地 webhook（另开终端）:"
  echo "  stripe listen --forward-to localhost:9000/api/membership/stripe/webhook"
fi
