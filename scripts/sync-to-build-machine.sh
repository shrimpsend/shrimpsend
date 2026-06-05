#!/usr/bin/env bash
# 从 ops 仓同步生产配置到业务仓（部署 / 官方打包前执行）
# 若缺少 scripts/bin/linux/centrifugo，会从 centrifugo-bins 仓自动下载
# 用法（在业务仓根目录）:
#   ./scripts/sync-to-build-machine.sh
#   ULTRASEND_OPS_DIR=/path/to/ops ./scripts/sync-to-build-machine.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/ops-common.sh
source "$ROOT/scripts/lib/ops-common.sh"
# shellcheck source=lib/ensure-centrifugo.sh
source "$ROOT/scripts/lib/ensure-centrifugo.sh"
OPS_DIR="$(resolve_ultrasend_ops_dir "$ROOT")"

ensure_centrifugo_linux_bin "$ROOT"

echo "==> 同步 ops 配置 from $OPS_DIR"

# 后端 prod profile
if [ -f "$OPS_DIR/cn/application-prod.yml" ]; then
  cp "$OPS_DIR/cn/application-prod.yml" "$ROOT/backend/src/main/resources/application-prod.yml"
  echo "  backend/application-prod.yml"
fi
if [ -f "$OPS_DIR/overseas/application-prod-overseas.yml" ]; then
  cp "$OPS_DIR/overseas/application-prod-overseas.yml" "$ROOT/backend/src/main/resources/application-prod-overseas.yml"
  echo "  backend/application-prod-overseas.yml"
fi

# Centrifugo bare-metal
if [ -f "$OPS_DIR/cn/config.prod.bare.json" ]; then
  cp "$OPS_DIR/cn/config.prod.bare.json" "$ROOT/config.prod.bare.json"
  echo "  config.prod.bare.json"
fi
if [ -f "$OPS_DIR/overseas/config.prod-overseas.bare.json" ]; then
  cp "$OPS_DIR/overseas/config.prod-overseas.bare.json" "$ROOT/config.prod-overseas.bare.json"
  echo "  config.prod-overseas.bare.json"
fi

# Flutter OpenPanel overlay（官方 App 打包）
if [ -f "$OPS_DIR/flutter/openpanel_env.secrets.dart" ]; then
  cp "$OPS_DIR/flutter/openpanel_env.secrets.dart" "$ROOT/app/lib/config/openpanel_env.secrets.dart"
  echo "  app/lib/config/openpanel_env.secrets.dart"
fi

# Flutter RC 公钥 / 生产 API URL（官方 App 打包）
if [ -f "$OPS_DIR/flutter/env.secrets.dart" ]; then
  cp "$OPS_DIR/flutter/env.secrets.dart" "$ROOT/app/lib/config/env.secrets.dart"
  echo "  app/lib/config/env.secrets.dart"
fi

# Web（原 web/.env → web/.env.local）
if [ -f "$OPS_DIR/web/.env.local" ]; then
  cp "$OPS_DIR/web/.env.local" "$ROOT/web/.env.local"
  echo "  web/.env.local"
fi

# HarmonyOS 签名
if [ -f "$OPS_DIR/harmonyos/build-profile.json5" ]; then
  cp "$OPS_DIR/harmonyos/build-profile.json5" "$ROOT/app_ohos/build-profile.json5"
  echo "  app_ohos/build-profile.json5"
fi

echo "==> 完成"
