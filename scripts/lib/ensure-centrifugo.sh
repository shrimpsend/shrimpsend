#!/usr/bin/env bash
# Ensure Centrifugo binaries exist under scripts/bin/{linux,mac}/ from centrifugo-bins repo.

CENTRIFUGO_BINS_REPO="${CENTRIFUGO_BINS_REPO:-git@github.com:shrimpsend/centrifugo-bins.git}"
CENTRIFUGO_BINS_BRANCH="${CENTRIFUGO_BINS_BRANCH:-main}"

_ensure_cf_die() {
  echo "[错误] $*" >&2
  exit 1
}

_ensure_cf_hint() {
  cat >&2 <<'EOF'
请检查:
  - git 与 SSH 访问 git@github.com:shrimpsend/centrifugo-bins.git
  - 或手动运行: ./scripts/install-centrifugo.sh
  - 环境变量 CENTRIFUGO_BINS_REPO / CENTRIFUGO_BINS_BRANCH
EOF
}

# centrifugo_bin_present DEST — file exists, executable, non-empty (no exec test)
centrifugo_bin_present() {
  local dest="$1"
  [ -f "$dest" ] && [ -x "$dest" ] && [ -s "$dest" ]
}

# centrifugo_linux_bin_valid DEST — ELF amd64 on disk (cross-platform safe)
centrifugo_linux_bin_valid() {
  local dest="$1"
  centrifugo_bin_present "$dest" || return 1
  if command -v file >/dev/null 2>&1; then
    file -b "$dest" | grep -q 'ELF.*x86-64'
    return $?
  fi
  return 0
}

# centrifugo_mac_bin_valid DEST — Mach-O arm64 on disk
centrifugo_mac_bin_valid() {
  local dest="$1"
  centrifugo_bin_present "$dest" || return 1
  if command -v file >/dev/null 2>&1; then
    file -b "$dest" | grep -q 'Mach-O.*arm64'
    return $?
  fi
  return 0
}

# fetch_centrifugo_platform_from_bins ROOT PLATFORM — copy scripts/bin/PLATFORM/centrifugo
fetch_centrifugo_platform_from_bins() {
  local root="$1"
  local platform="$2"
  local repo="$CENTRIFUGO_BINS_REPO"
  local branch="$CENTRIFUGO_BINS_BRANCH"
  local tmpdir dest src

  command -v git >/dev/null 2>&1 || _ensure_cf_die "未找到 git，无法从 centrifugo-bins 下载"

  dest="$root/scripts/bin/$platform/centrifugo"
  mkdir -p "$root/scripts/bin/$platform"

  tmpdir="$(mktemp -d)"

  echo "==> 从 centrifugo-bins 下载 Centrifugo ($platform/)"
  echo "    $repo (branch: $branch)"

  if ! git clone --depth 1 --branch "$branch" --filter=blob:none --sparse "$repo" "$tmpdir" 2>&1; then
    rm -rf "$tmpdir"
    _ensure_cf_hint
    _ensure_cf_die "git clone centrifugo-bins 失败"
  fi

  if ! (cd "$tmpdir" && git sparse-checkout set "$platform"); then
    rm -rf "$tmpdir"
    _ensure_cf_hint
    _ensure_cf_die "sparse-checkout $platform 失败"
  fi

  src="$tmpdir/$platform/centrifugo"
  if [ ! -f "$src" ]; then
    rm -rf "$tmpdir"
    _ensure_cf_hint
    _ensure_cf_die "centrifugo-bins 中未找到 $platform/centrifugo"
  fi

  cp "$src" "$dest"
  chmod +x "$dest"
  rm -rf "$tmpdir"
  echo "    已安装: $dest"
}

# _centrifugo_runnable_on_host ROOT DEST
_centrifugo_runnable_on_host() {
  local root="$1"
  local dest="$2"
  # shellcheck source=dev-common.sh
  source "$root/scripts/lib/dev-common.sh"
  ROOT="$root"
  centrifugo_runnable "$dest"
}

# ensure_centrifugo_linux_bin ROOT — for production deploy / sync-to-build-machine
ensure_centrifugo_linux_bin() {
  local root="$1"
  local dest="$root/scripts/bin/linux/centrifugo"

  if centrifugo_linux_bin_valid "$dest"; then
    if [ "$(uname -s)" = "Linux" ] && ! _centrifugo_runnable_on_host "$root" "$dest"; then
      echo "  [警告] $dest 存在但无法在本机运行，将重新下载"
      rm -f "$dest"
    else
      echo "==> Centrifugo linux 二进制已就绪: scripts/bin/linux/centrifugo"
      return 0
    fi
  elif centrifugo_bin_present "$dest"; then
    echo "  [警告] $dest 格式无效，将重新下载"
    rm -f "$dest"
  fi

  fetch_centrifugo_platform_from_bins "$root" linux

  if ! centrifugo_linux_bin_valid "$dest"; then
    _ensure_cf_die "下载后 Centrifugo 无效: $dest"
  fi

  if [ "$(uname -s)" = "Linux" ] && ! _centrifugo_runnable_on_host "$root" "$dest"; then
    _ensure_cf_die "下载的 Centrifugo 无法在本机运行: $dest"
  fi
}

# ensure_centrifugo_platform_bin ROOT PLATFORM — for install-centrifugo (mac or linux)
ensure_centrifugo_platform_bin() {
  local root="$1"
  local platform="$2"
  local dest="$root/scripts/bin/$platform/centrifugo"

  mkdir -p "$root/scripts/bin/$platform"

  if [ "$platform" = "linux" ]; then
    if centrifugo_linux_bin_valid "$dest"; then
      if [ "$(uname -s)" = "Linux" ] && ! _centrifugo_runnable_on_host "$root" "$dest"; then
        rm -f "$dest"
      else
        return 0
      fi
    elif centrifugo_bin_present "$dest"; then
      rm -f "$dest"
    fi
    fetch_centrifugo_platform_from_bins "$root" linux
    return 0
  fi

  if [ "$platform" = "mac" ]; then
    if centrifugo_mac_bin_valid "$dest"; then
      if [ "$(uname -s)" = "Darwin" ] && ! _centrifugo_runnable_on_host "$root" "$dest"; then
        rm -f "$dest"
      else
        return 0
      fi
    elif centrifugo_bin_present "$dest"; then
      rm -f "$dest"
    fi
    fetch_centrifugo_platform_from_bins "$root" mac
    return 0
  fi

  _ensure_cf_die "未知 platform: $platform"
}
