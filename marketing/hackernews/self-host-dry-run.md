# Self-host 实测流程（发帖前必做）

目标：发帖前，找 3–5 位开发者**只看公开文档**，从一台干净机器跑通自托管实例，并修掉他们遇到的每一个文档坑。发帖当天「我试着自托管但跑不起来」是杀伤力最强的评论；这是最便宜的预防办法。

## 招募

- 找 3–5 个**没搭过本项目**的人（陌生感正是关键）。
- 操作系统尽量混合：至少一台 macOS（arm64）、一台 Linux x86_64，最好有一台 Windows（WSL）。
- 他们只能用公开 [README](../../README.md) + [docs/SELF_HOST.md](../../docs/SELF_HOST.md)，**不准私下问维护者**。他们每问你一个问题，就是一个文档 bug。

## 被测路径

HN 访客最先走的就是这条：

```bash
git clone https://github.com/shrimpsend/shrimpsend.git
cd shrimpsend
./scripts/setup-local-config.sh
docker compose up -d
cd web && npm ci && npm run dev
# 打开 http://localhost:3000，注册，加第二台设备/浏览器，发一条消息
```

## 测试卡片（每位测试者填一份）

```
测试者：            ______________________
系统 / 架构：        ______________________
日期：              ______________________
clone 到跑起来：     ____ 分钟
卡在哪一步：         ______________________
确切报错：           ______________________
发现的文档坑：       ______________________
成功发出第一条消息？(是/否)
两设备间局域网传输成功？(是/否/未测)
备注：              ______________________
```

## 验收项

- [ ] `git clone` + `setup-local-config.sh` 不用手动改任何东西就能生成可用的 `.env` 和 `config.docker.json`（或所需的手动修改已写进文档）。
- [ ] `docker compose up -d` 能把 MySQL、Centrifugo、backend 拉到 healthy。
- [ ] Web 客户端能启动并连上 :9000 的后端。
- [ ] 能在自托管实例上注册账号。
- [ ] 第二台设备/浏览器能加入并收到一条文本消息。
- [ ]（若有两台真机）局域网直连传输能成功。
- [ ] 干净机器从 clone 到第一条消息总耗时低于约 10 分钟。

## 重点排查的失败点

- 端口被占用（3306 / 8000 / 9000 / 3000）。
- 首次启动 MySQL healthcheck 超时（磁盘慢 / arm64 拉镜像慢）。
- Centrifugo 镜像版本不一致（[docker-compose.yml](../../docker-compose.yml) 固定 `centrifugo:v5`，而 README/SELF_HOST 写的是 v6——确认 compose 路径到底需要哪个并统一）。
- 缺失或占位的 Centrifugo 密钥，导致后端拒绝 WebSocket 连接。
- Node < 20 导致 `npm ci` 失败。

## 产出

测试者遇到的每个坑，要么当周修文档/脚本，要么开 issue 跟踪。反复实测，直到一位全新测试者**零场外提问**就能跑到「发出第一条消息」。到这一步，才能在发帖剧本里勾上「3 位测试者成功」那一项。
