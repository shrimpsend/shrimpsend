# Self-Hosting Guide

This document describes how to run ShrimpSend / 虾传 on your own infrastructure.

Chinese setup guide (including troubleshooting): [docs/README.zh-CN.md](README.zh-CN.md)

## Architecture

| Component | Default port | Notes |
|-----------|--------------|-------|
| MySQL 8 | 3306 | Primary database |
| Centrifugo v6 | 8000 | Real-time WebSocket |
| Spring Boot backend | 9000 | REST API |
| Next.js web | 3000 | Web client |

## Local development

All local stacks use `./scripts/start-dev.sh` to start Centrifugo, backend, and Web together. Stop with `./scripts/stop-dev.sh`. Logs: `scripts/logs/`.

### China logic (default profile)

**Maintainers** (private `ops/local/`):

```bash
chmod +x scripts/deploy-local.sh scripts/start-dev.sh scripts/stop-dev.sh
./scripts/deploy-local.sh    # sync ops/local + init MySQL (ultrasend + ultrasend_overseas)
./scripts/start-dev.sh
```

**Contributors** (examples only):

```bash
chmod +x scripts/setup-local-config.sh scripts/start-dev.sh scripts/stop-dev.sh
./scripts/setup-local-config.sh

# Create database manually, then:
./scripts/start-dev.sh
```

Contributors must create `ultrasend` in MySQL before the first start (maintainers: `deploy-local.sh` does this automatically unless `--skip-db`).

### Overseas / ShrimpSend logic (`dev-overseas`)

Same config step as above. Database: `ultrasend_overseas` (created by `deploy-local.sh` for maintainers).

```bash
./scripts/start-dev.sh --overseas
# Stop: ./scripts/stop-dev.sh
```

Stripe webhook (separate terminal, for membership testing):

```bash
stripe listen --forward-to localhost:9000/api/membership/stripe/webhook
```

**Backend only** (no Centrifugo/Web): `backend/scripts/run-dev-overseas.sh`

## Production deployment

Production runs on bare metal via `./scripts/deploy.sh`. Secrets live in an **ops** config directory (see [ops/README.md](../ops/README.md)).

### One-time server setup

1. Clone the public app repo and an ops config repo **as siblings**:

```bash
git clone git@github.com:shrimpsend/shrimpsend.git shrimpsend
cd shrimpsend

# Self-hosters: public samples (replace placeholders before production)
git clone git@github.com:shrimpsend/public-ops.git ../ops

# Maintainers: private production ops (requires access)
# git clone git@github.com:shrimpsend/ops.git ../ops
```

2. Optional: `export ULTRASEND_OPS_DIR=/path/to/your-ops` if ops is not at `../ops`.
3. Ensure Java 17+, Node.js, and MySQL are available on the server. **Centrifugo** (`scripts/bin/linux/centrifugo`, not in git) is installed automatically when you run `./scripts/sync-to-build-machine.sh` (sparse clone from [shrimpsend/centrifugo-bins](https://github.com/shrimpsend/centrifugo-bins)); manual fallback: `./scripts/install-centrifugo.sh`.

Scripts resolve ops in this order: `ULTRASEND_OPS_DIR` → sibling `../ops` → validate `.ultrasend-ops` marker and at least one config subdirectory (`cn/`, `overseas/`, `local/`, etc.).

### Deploy (interactive)

```bash
./scripts/deploy.sh
```

The script may:

- Pull latest git (confirm at prompt)
- Ask **China (xiachuan)** vs **Overseas (ShrimpSend)** cluster
- Optionally sync from ops (`sync-to-build-machine.sh`)
- Build backend JAR and Next.js standalone Web
- Restart Centrifugo (8000), backend (9000), Web (3000)

You can run `scripts/sync-to-build-machine.sh` before `deploy.sh`; the deploy script can sync again when prompted.

### Deploy (non-interactive)

China (default):

```bash
SPRING_PROFILE=prod CLUSTER_LABEL='China (xiachuan)' ./scripts/deploy.sh
```

Overseas:

```bash
SPRING_PROFILE=prod-overseas CLUSTER_LABEL='Overseas (ShrimpSend)' ./scripts/deploy.sh
```

Overseas Web builds with `NEXT_PUBLIC_STRIPE_BILLING=live` automatically.

### Operations

```bash
./scripts/deploy.sh stop
./scripts/deploy.sh status
./scripts/deploy.sh logs
```

### Spring profiles (reference)

| Profile | Use case |
|---------|----------|
| (default) | Local dev — China logic |
| `dev-overseas` | Local dev — ShrimpSend logic (`start-dev.sh --overseas`) |
| `prod` | China production (`application-prod.yml` from ops) |
| `prod-overseas` | ShrimpSend production |

### Environment variables (backend)

See [backend/.env.example](../backend/.env.example). Critical production values:

- `SPRING_DATASOURCE_*` — database
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`
- `APP_MESSAGES_ENCRYPTION_KEY_BASE64` — AES-GCM key for legacy cloud-stored message text (`enc:v1:`)
- `APP_USER_DATA_ENCRYPTION_KEK_BASE64` — server KEK wrapping per-user DEKs (S3 SK, new message text `enc:u:v1:`)
- `APP_USER_DATA_ENCRYPTION_MIGRATE_S3_ON_STARTUP` / `APP_USER_DATA_ENCRYPTION_MIGRATE_MESSAGES_ON_STARTUP` — one-shot migration switches
- `CENTRIFUGO_HTTP_API_KEY`, `CENTRIFUGO_TOKEN_HMAC_SECRET` (must match Centrifugo JSON)
- `ALIPAY_*` — China payments (optional overseas)
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` — overseas
- `REVENUECAT_WEBHOOK_AUTH`
- `TENCENT_SMS_*` — China SMS (optional)
- `HOSTED_S3_*`, `STORAGE_S3_*` — object storage

## Configuration layers

| Layer | Public repo | Your secrets |
|-------|-------------|--------------|
| Local dev (team) | `*.example` templates | `ops/local/` → `./scripts/deploy-local.sh` |
| Local dev (minimal) | `config.json`, `application.yml` | `./scripts/setup-local-config.sh` |
| Docker | `.env` from `.env.example` | Local `.env` (or `ops/local/docker.env`) |
| Web | `web/.env.example` | `web/.env.local` (sync from `ops/web/.env.local`) |
| Flutter OpenPanel | `openpanel_env.secrets.example.dart` | `openpanel_env.secrets.dart` (gitignored) |
| Flutter RC / prod URLs | `env.secrets.example.dart` | `env.secrets.dart` (gitignored) |
| Production | `*.example.yml`, `config.prod.example.bare.json` | [public-ops](https://github.com/shrimpsend/public-ops) samples or private ops → `sync-to-build-machine.sh` |

## Docker (optional)

Containerized MySQL + Centrifugo + backend. Web is not included in Compose.

```bash
./scripts/setup-local-config.sh   # creates .env from .env.example if missing
docker compose up -d
```

For the Web UI, run `./scripts/start-dev.sh` on the host (or `cd web && npm run dev`). Compose uses `config.docker.json` (proxy to `backend:9000`); local shell scripts use `config.json` (localhost).

## Flutter / mobile builds

Official release builds read RevenueCat public keys, production API/WS URLs, and OpenPanel client ids from gitignored `app/lib/config/env.secrets.dart` and `openpanel_env.secrets.dart` (synced from `ops/flutter/`). See `app/lib/config/env.dart` for dart-define overrides.

```bash
# iOS cn / intl (on macOS)
cd app && ./scripts/package_ios.sh --all
```

HarmonyOS: copy `build-profile.example.json5` → `build-profile.json5` or sync from ops.

## Dual cluster (cn vs overseas)

| | China (xiachuan) | Overseas (ShrimpSend) |
|--|------------------|-------------------------|
| API | `api.xiachuan.net` | `api.shrimpsend.com` |
| Spring profile | `prod` | `prod-overseas` |
| Centrifugo config | `config.prod.bare.json` | `config.prod-overseas.bare.json` |
| Flutter | `--dart-define=OVERSEAS_BUILD=false`, flavor `cn` | `OVERSEAS_BUILD=true`, flavor `intl` |
| Local start | `./scripts/start-dev.sh` | `./scripts/start-dev.sh --overseas` |

## Open-sourcing note

Before publishing to GitHub, rotate all credentials that ever appeared in Git history and run [scripts/prepare-public-mirror.sh](../scripts/prepare-public-mirror.sh) to scrub history.
