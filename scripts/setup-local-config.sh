#!/usr/bin/env bash
# 首次本地开发：从 example 模板生成本地配置（可重复执行，不覆盖已有文件）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/ops-common.sh
source "$ROOT/scripts/lib/ops-common.sh"
cd "$ROOT"

copy_if_missing() {
  local src="$1"
  local dest="$2"
  if [ -f "$dest" ]; then
    echo "  保留已有: $dest"
  elif [ -f "$src" ]; then
    cp "$src" "$dest"
    echo "  已创建: $dest"
  else
    echo "  [跳过] 模板不存在: $src"
  fi
}

echo "==> 生成本地配置文件"

copy_if_missing "$ROOT/config.example.json" "$ROOT/config.json"
copy_if_missing "$ROOT/.env.example" "$ROOT/.env"
copy_if_missing "$ROOT/web/.env.example" "$ROOT/web/.env.local"
copy_if_missing \
  "$ROOT/app/lib/config/openpanel_env.secrets.example.dart" \
  "$ROOT/app/lib/config/openpanel_env.secrets.dart"
copy_if_missing \
  "$ROOT/app/lib/config/env.secrets.example.dart" \
  "$ROOT/app/lib/config/env.secrets.dart"
copy_if_missing "$ROOT/backend/.env.example" "$ROOT/backend/.env"
copy_if_missing \
  "$ROOT/app_ohos/build-profile.example.json5" \
  "$ROOT/app_ohos/build-profile.json5"

if command -v openssl >/dev/null 2>&1; then
  if [ -f "$ROOT/backend/.env" ] && ! grep -q '^APP_MESSAGES_ENCRYPTION_KEY_BASE64=.\+' "$ROOT/backend/.env" 2>/dev/null; then
    MSG_KEY="$(openssl rand -base64 32)"
    if grep -q '^APP_MESSAGES_ENCRYPTION_KEY_BASE64=' "$ROOT/backend/.env" 2>/dev/null; then
      if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY
from pathlib import Path
p = Path("$ROOT/backend/.env")
lines = p.read_text().splitlines()
out = []
for line in lines:
    if line.startswith("APP_MESSAGES_ENCRYPTION_KEY_BASE64="):
        out.append("APP_MESSAGES_ENCRYPTION_KEY_BASE64=$MSG_KEY")
    else:
        out.append(line)
p.write_text("\n".join(out) + "\n")
PY
      else
        echo "APP_MESSAGES_ENCRYPTION_KEY_BASE64=$MSG_KEY" >> "$ROOT/backend/.env"
      fi
    else
      echo "APP_MESSAGES_ENCRYPTION_KEY_BASE64=$MSG_KEY" >> "$ROOT/backend/.env"
    fi
    echo "  已生成 backend/.env 消息加密 key (APP_MESSAGES_ENCRYPTION_KEY_BASE64)"
  fi

  if [ -f "$ROOT/backend/.env" ] && ! grep -q '^APP_USER_DATA_ENCRYPTION_KEK_BASE64=.\+' "$ROOT/backend/.env" 2>/dev/null; then
    USER_KEK="$(openssl rand -base64 32)"
    if grep -q '^APP_USER_DATA_ENCRYPTION_KEK_BASE64=' "$ROOT/backend/.env" 2>/dev/null; then
      if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY
from pathlib import Path
p = Path("$ROOT/backend/.env")
lines = p.read_text().splitlines()
out = []
for line in lines:
    if line.startswith("APP_USER_DATA_ENCRYPTION_KEK_BASE64="):
        out.append("APP_USER_DATA_ENCRYPTION_KEK_BASE64=$USER_KEK")
    else:
        out.append(line)
p.write_text("\n".join(out) + "\n")
PY
      else
        echo "APP_USER_DATA_ENCRYPTION_KEK_BASE64=$USER_KEK" >> "$ROOT/backend/.env"
      fi
    else
      echo "APP_USER_DATA_ENCRYPTION_KEK_BASE64=$USER_KEK" >> "$ROOT/backend/.env"
    fi
    echo "  已生成 backend/.env 用户数据加密 KEK (APP_USER_DATA_ENCRYPTION_KEK_BASE64)"
  fi

  if grep -q 'dev-centrifugo-hmac-secret-change-me' "$ROOT/config.json" 2>/dev/null; then
    HMAC="$(openssl rand -base64 48 | tr -d '/+=' | head -c 64)"
    API_KEY="$(openssl rand -base64 48 | tr -d '/+=' | head -c 64)"
    ADMIN_PW="$(openssl rand -base64 18 | tr -d '/+=' | head -c 24)"
    ADMIN_SEC="$(openssl rand -base64 48 | tr -d '/+=' | head -c 64)"
    if command -v python3 >/dev/null 2>&1; then
      python3 - <<PY
import json
from pathlib import Path
p = Path("$ROOT/config.json")
cfg = json.loads(p.read_text())
cfg["client"]["token"]["hmac_secret_key"] = "$HMAC"
cfg["http_api"]["key"] = "$API_KEY"
cfg["admin"]["password"] = "$ADMIN_PW"
cfg["admin"]["secret"] = "$ADMIN_SEC"
p.write_text(json.dumps(cfg, indent=2) + "\n")
PY
      echo "  已随机化 config.json 中的 Centrifugo 密钥"
      echo "  start-dev.sh 会从 config.json 导出 CENTRIFUGO_* 到后端进程"
    fi
  fi
fi

echo ""
echo "下一步:"
_OPS_DIR=""
if _OPS_DIR="$(try_resolve_ultrasend_ops_dir "$ROOT")" && [ -d "$_OPS_DIR/local" ]; then
  echo "  检测到 ops/local，正在同步团队本地配置..."
  ULTRASEND_OPS_DIR="$_OPS_DIR" "$ROOT/scripts/sync-to-local.sh"
else
  echo "  1. 准备 MySQL（见 README.md）"
  echo "  2. ./scripts/start-dev.sh"
  echo ""
  echo "维护者本地调试: clone public-ops 到 ../ops 后 ./scripts/deploy-local.sh（见 ops/README.md）"
fi
echo ""
echo "生产部署 / 官方打包: 从 ops 仓 sync（见 ops/README.md）"
echo "  含 web/.env.local、app/lib/config/env.secrets.dart、openpanel_env.secrets.dart"
