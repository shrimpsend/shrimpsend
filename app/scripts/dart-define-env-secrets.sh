#!/usr/bin/env bash
# 从环境变量追加 Flutter --dart-define（RC 公钥、生产 URL、Stripe Price 等）。
# 用法（在 build 脚本中）:
#   DART_DEFINE_SECRETS=()
#   # shellcheck disable=SC1091
#   source "$APP_ROOT/scripts/dart-define-env-secrets.sh"
#   append_dart_define_secrets DART_DEFINE_SECRETS
#   COMMON+=("${DART_DEFINE_SECRETS[@]}")
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/lib/ops-common.sh
source "$_REPO_ROOT/scripts/lib/ops-common.sh"
_OPS_DIR=""
if _OPS_DIR="$(try_resolve_ultrasend_ops_dir "$_REPO_ROOT")"; then
  _BUILD_ENV="$_OPS_DIR/flutter/build.env"
else
  _BUILD_ENV=""
fi
if [ -n "$_BUILD_ENV" ] && [ -f "$_BUILD_ENV" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$_BUILD_ENV"
  set +a
fi

append_dart_define_secrets() {
  local _arr_name=$1
  local _key _val
  local _keys=(
    RC_TEST_STORE_API_KEY
    RC_APPLE_API_KEY_CN
    RC_APPLE_API_KEY_INTL
    RC_GOOGLE_API_KEY
    API_URL_PROD_CN
    CENTRIFUGO_WS_PROD_CN
    API_URL_PROD_INTL
    CENTRIFUGO_WS_PROD_INTL
    STRIPE_PRICE_PLUS_MONTHLY
    STRIPE_PRICE_PLUS_YEARLY
    STRIPE_PRICE_PRO_MONTHLY
    STRIPE_PRICE_PRO_YEARLY
    STRIPE_PRICE_ULTRA_MONTHLY
    STRIPE_PRICE_ULTRA_YEARLY
    OP_CN_APP_CLIENT_ID
    OP_CN_APP_CLIENT_SECRET
    OP_CN_API_BASE
    OP_INTL_APP_CLIENT_ID
    OP_INTL_APP_CLIENT_SECRET
    OP_INTL_API_BASE
  )
  for _key in "${_keys[@]}"; do
    _val="${!_key:-}"
    if [[ -n "$_val" ]]; then
      eval "${_arr_name}+=(\"--dart-define=${_key}=$(printf '%q' "$_val")\")"
    fi
  done
}
