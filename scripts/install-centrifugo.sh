#!/usr/bin/env bash
# 下载与当前 OS/arch 匹配的 Centrifugo 到 scripts/bin/centrifugo（本地开发用）
# 用法: ./scripts/install-centrifugo.sh
# 可选: CENTRIFUGO_VERSION=6.8.1 ./scripts/install-centrifugo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${CENTRIFUGO_VERSION:-6.8.1}"
DEST="$ROOT/scripts/bin/centrifugo"
mkdir -p "$ROOT/scripts/bin"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$arch" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64) arch=amd64 ;;
  *)
    echo "[错误] 不支持的 CPU 架构: $(uname -m)" >&2
    exit 1
    ;;
esac
case "$os" in
  darwin) os=darwin ;;
  linux) os=linux ;;
  *)
    echo "[错误] 不支持的操作系统: $(uname -s)" >&2
    exit 1
    ;;
esac

asset="centrifugo_${VERSION}_${os}_${arch}.tar.gz"
url="https://github.com/centrifugal/centrifugo/releases/download/v${VERSION}/${asset}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "==> 下载 Centrifugo v${VERSION} (${os}_${arch})"
echo "    $url"
if ! curl -fsSL "$url" -o "$tmpdir/$asset"; then
  echo "[错误] 下载失败。可设置 CENTRIFUGO_VERSION 或从 https://github.com/centrifugal/centrifugo/releases 手动安装" >&2
  exit 1
fi

tar -xzf "$tmpdir/$asset" -C "$tmpdir"
bin="$(find "$tmpdir" -name centrifugo -type f | head -1)"
if [ -z "$bin" ]; then
  echo "[错误] 压缩包内未找到 centrifugo 可执行文件" >&2
  exit 1
fi

cp "$bin" "$DEST"
chmod +x "$DEST"

if ! "$DEST" version; then
  echo "[错误] 安装后无法运行 $DEST" >&2
  exit 1
fi

echo "==> 已安装: $DEST"
echo "    生产/Linux 部署仍可使用 $ROOT/bin/centrifugo（linux_amd64 等）"
echo "    本地启动: ./scripts/start-dev.sh"
