# ShrimpSend ops 运维配置

本目录说明 **ultrasend / ShrimpSend** 运维配置（ops）的获取、校验与同步方式。真实密钥**不应**进入公开业务仓 Git 历史。

## 获取 ops 配置

### 推荐布局（平级 clone）

业务仓与 ops **平级**放置，脚本会自动发现 `../ops`：

```
/path/to/
├── ultrasend/          # 业务仓 git@github.com:shrimpsend/shrimpsend.git
└── ops/                # 配置仓（见下方 clone 源）
```

```bash
git clone git@github.com:shrimpsend/shrimpsend.git ultrasend
cd ultrasend

# 自托管 / 贡献者：公开样例（占位值，生产前须替换）
git clone git@github.com:shrimpsend/public-ops.git ../ops

# 维护者：私有生产配置
git clone git@github.com:shrimpsend/ops.git ../ops
```

### 解析顺序

业务仓脚本按以下顺序定位 ops 根目录：

1. **环境变量** `ULTRASEND_OPS_DIR`（若已设置）
2. **平级目录** `../ops`（相对业务仓根目录）
3. 未找到或未通过校验 → **报错退出**（不再 fallback 到业务仓内 `ops/`）

自定义路径示例：

```bash
export ULTRASEND_OPS_DIR=/path/to/your-ops
./scripts/sync-to-build-machine.sh
```

### 校验特征

ops 根目录须同时满足：

- 存在 marker 文件 **`.ultrasend-ops`**，首行内容为 `ultrasend-ops`
- 至少存在一个配置子目录：`cn/`、`overseas/`、`local/`、`flutter/`、`web/`、`harmonyos/`

维护者若将真实载荷放在业务仓内 `ops/`（gitignored），可显式设置：

```bash
export ULTRASEND_OPS_DIR="$PWD/ops"
```

### 公开样例 vs 私有 ops

| 仓库 | 用途 |
|------|------|
| [shrimpsend/public-ops](https://github.com/shrimpsend/public-ops) | 公开占位样例，自托管起点 |
| `git@github.com:shrimpsend/ops.git`（私有） | 官方生产配置 |

## 脚本位置（重要）

**本地启动 / 停止** 与 **从 ops 同步到业务仓** 的脚本在**公开业务仓** [`scripts/`](../scripts/)（以业务仓为 `ROOT`，才能正确访问 `web/`、`backend/` 等路径）：

| 用途 | 命令（在业务仓根目录） |
|------|------------------------|
| 同步本地配置 + 建库 | `./scripts/deploy-local.sh` 或 `./scripts/sync-to-local.sh` |
| 启动 Centrifugo + 后端 + Web | `./scripts/start-dev.sh` / `./start-dev.sh` |
| 停止 | `./scripts/stop-dev.sh` / `./stop-dev.sh` |
| 同步生产配置 | `./scripts/sync-to-build-machine.sh` |
| 生产部署 | `./scripts/deploy.sh` |

`ops/scripts/` 下仅为兼容旧路径的转发，请始终在 clone 的 **shrimpsend** 业务仓中执行上述命令。

## 目录结构（ops 仓内仅配置）

```
ops/
├── .ultrasend-ops               # marker（勿删）
├── cn/                          # 国内 (xiachuan)
│   ├── application-prod.yml
│   └── config.prod.bare.json
├── overseas/                    # 海外 (ShrimpSend)
│   ├── application-prod-overseas.yml
│   └── config.prod-overseas.bare.json
├── local/                       # 本地调试（Centrifugo、dev-overseas、backend.env）
│   ├── config.json
│   ├── backend.env
│   ├── application-dev-overseas.yml
│   └── docker.env               # 可选
├── flutter/
│   ├── openpanel_env.secrets.dart   # OpenPanel client id/secret/ingest URL
│   ├── env.secrets.dart             # RevenueCat 公钥、生产 API/WS URL
│   └── build.env                    # Stripe Price 等构建时 dart-define 源（可选）
├── web/
│   └── .env.local               # Stripe Price + OpenPanel Web
├── harmonyos/
│   └── build-profile.json5
└── scripts/                     # 兼容转发 → 业务仓 scripts/sync-*.sh
```

## 本地调试（一键同步 + 建库）

维护者 clone **业务仓** 与 **ops**（平级 `../ops` 或 `ULTRASEND_OPS_DIR`）后：

```bash
./scripts/deploy-local.sh
# 仅同步配置、跳过建库：./scripts/deploy-local.sh --skip-db
```

同步目标：

| ops/local | 业务仓 |
|-----------|--------|
| `config.json` | `config.json` |
| `application-dev-overseas.yml` | `backend/src/main/resources/application-dev-overseas.yml` |
| `backend.env` | `backend/.env` |
| `docker.env` | `.env`（Docker Compose） |
| `web/.env.local` 或 `ops/web/.env.local` | `web/.env.local` |
| `local/flutter/env.secrets.dart` 或 `ops/flutter/env.secrets.dart` | `app/lib/config/env.secrets.dart` |
| `local/flutter/openpanel_env.secrets.dart` 或 `ops/flutter/openpanel_env.secrets.dart` | `app/lib/config/openpanel_env.secrets.dart` |

启动 / 停止（在**业务仓**根目录，勿在仅 clone 的 ops 仓内执行）：

- 国内：`./scripts/start-dev.sh` 或 `./start-dev.sh`
- 海外：`./scripts/start-dev.sh --overseas`
- 停止：`./scripts/stop-dev.sh` 或 `./stop-dev.sh`

仅调试后端（不启 Centrifugo/Web）：`backend/scripts/run-dev-overseas.sh`

## 同步到业务仓（部署 / 打包前）

```bash
./scripts/sync-to-build-machine.sh
# 或自定义 ops 路径：
ULTRASEND_OPS_DIR=/path/to/ops ./scripts/deploy.sh
```

**后台管理员邮箱**（前后端须一致；国内/海外 Web 共用 `web/.env.local`）：

| 集群 | 后端 |
|------|------|
| 国内 prod | `cn/application-prod.yml` → `app.admin.emails` |
| 海外 prod | `overseas/application-prod-overseas.yml` → `app.admin.emails` |
| 本地 dev-overseas | `local/application-dev-overseas.yml` → `app.admin.emails` |

前端：`NEXT_PUBLIC_ADMIN_EMAILS`（海外 `deploy.sh` 构建同样使用）

**发行包上传**（`storage.s3.*`）：国内 prod → COS（`cn/application-prod.yml`）；海外 prod / dev-overseas → R2。详见 `docs/release-upload-direct.md`。

`ops/flutter/env.secrets.dart` 含 RevenueCat SDK 公钥（`test_`/`appl_`/`goog_`）与生产 API/WS URL；构建脚本亦支持通过环境变量 `--dart-define` 覆盖（见 `app/scripts/dart-define-env-secrets.sh`，从 resolved ops 读取 `flutter/build.env`）。

## 凭证轮换清单（开源公开前必须完成）

以下凭证曾出现在 Git 历史中，**公开前请全部轮换**：

| 服务 | 轮换位置 |
|------|----------|
| MySQL | 国内 / 海外数据库密码 |
| JWT | `access-secret` / `refresh-secret`（国内与海外独立） |
| 消息加密 | `APP_MESSAGES_ENCRYPTION_KEY_BASE64` |
| 支付宝 | RSA 私钥（最高优先级） |
| Stripe | `sk_live_*`、`whsec_*` |
| RevenueCat | Webhook Bearer token |
| RevenueCat SDK 公钥 | `ops/flutter/env.secrets.dart`（虽为客户端公钥，开源前建议轮换或移出源码历史） |
| Cloudflare R2 | access-key-id / secret-access-key |
| 腾讯云 COS / SMS | SecretId / SecretKey |
| SendCloud | api-key |
| Centrifugo | HMAC secret、admin password、HTTP API key（国内/海外独立） |
| OpenPanel | `ops/web/.env.local`、`ops/flutter/openpanel_env.secrets.dart` |
| HarmonyOS | keystore storePassword / keyPassword |

轮换完成后更新 ops 目录内对应文件，再执行 `sync-to-build-machine.sh` 同步到业务仓。
