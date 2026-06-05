#!/usr/bin/env bash
# 本地开发一键启动（Centrifugo + 后端 + Web）。实现见 scripts/start-dev.sh

if [ -z "${BASH_VERSION:-}" ]; then
  exec env bash "$0" "$@"
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/scripts/start-dev.sh" "$@"
