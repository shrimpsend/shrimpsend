#!/usr/bin/env bash
# 下载与当前 OS/arch 匹配的 Centrifugo 到 scripts/bin/{mac,linux}/centrifugo
# 优先从 shrimpsend/centrifugo-bins 获取；失败则回退官方 Release
# 用法: ./scripts/install-centrifugo.sh
# 可选: CENTRIFUGO_VERSION=6.8.1 ./scripts/install-centrifugo.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/dev-common.sh
source "$ROOT/scripts/lib/dev-common.sh"
# shellcheck source=lib/ensure-centrifugo.sh
source "$ROOT/scripts/lib/ensure-centrifugo.sh"

VERSION="${CENTRIFUGO_VERSION:-6.8.1}"
platform="$(centrifugo_platform_subdir)"
if [ -z "$platform" ]; then
  echo "[错误] 不支持的操作系统: $(uname -s)" >&2
  exit 1
fi

DEST="$ROOT/scripts/bin/$platform/centrifugo"
mkdir -p "$ROOT/scripts/bin/$platform"

if ( ensure_centrifugo_platform_bin "$ROOT" "$platform" && centrifugo_runnable "$DEST" ); then
  echo "==> 已从 centrifugo-bins 安装: $DEST"
  "$DEST" version
  echo "    生产部署使用: $ROOT/scripts/bin/linux/centrifugo"
  echo "    本地启动: ./scripts/start-dev.sh"
  exit 0
fi

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

echo "==> centrifugo-bins 不可用，从官方 Release 下载 Centrifugo v${VERSION} (${os}_${arch})"
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
echo "    生产部署使用: $ROOT/scripts/bin/linux/centrifugo"
echo "    本地启动: ./scripts/start-dev.sh"
