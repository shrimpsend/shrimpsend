# Good first issues 待发清单

发帖前要发布的 8 个对贡献者友好的 issue。一个可见的 `good first issue` 列表能把 HN 流量转成贡献者，而不只是 stargazer。

> 说明：下面每条的标题（Title）和正文（Body）是要发到 GitHub 给国际贡献者看的，**保留英文**；说明和「为什么」用中文给你参考。

## 怎么发（在仓库里执行，需先 `gh auth login`）

```bash
gh label create "good first issue" --color 7057ff --description "Good for newcomers" --force
gh issue create --title "<Title>" --label "good first issue,<area>" --body "<Body>"
```

每个 issue 保持小（新手 2 小时内能搞定），写清验收标准和相关文件指引。不要指派，让贡献者在评论里认领。

---

## 1. docker-compose 故障排查文档

- 标签：`good first issue`、`documentation`、`self-hosting`
- 为什么：README 的 5 分钟路径是 HN 访客第一件会试的事；常见失败（端口被占、MySQL healthcheck 超时、缺 `config.docker.json`）值得一段简短 FAQ。
- Title：`Docs: add a docker-compose troubleshooting section`
- Body：

```text
The 5-minute Docker quickstart in the README is the first thing new users try.
Add a "Troubleshooting" subsection under the Docker instructions in docs/SELF_HOST.md
covering at least: port conflicts (3306/8000/9000/3000), MySQL healthcheck not ready on
first boot, and where logs live. Acceptance: the section exists and links from the README
quickstart.
```

中文译文：标题《Docs: 增加 docker-compose 故障排查章节》。正文：README 的 5 分钟 Docker 上手是新用户最先会试的东西。在 docs/SELF_HOST.md 的 Docker 说明下加一个「Troubleshooting」小节，至少覆盖：端口冲突（3306/8000/9000/3000）、首次启动 MySQL healthcheck 未就绪、日志在哪。验收：该小节存在，并从 README 上手处链接过去。

## 2. 首次运行的英文截图说明

- 标签：`good first issue`、`documentation`
- 为什么：README 截图展示了 UI，但没展示首次运行流程（在自己的实例上注册、加第二台设备）。
- Title：`Docs: add first-run walkthrough screenshots`
- Body：

```text
README screenshots show the UI but not the first-run flow. Add 3-4 annotated screenshots
or a short numbered list under "Try it in 5 minutes" in README.md: sign up on your own
instance, add a second device/browser, send the first message.
```

中文译文：标题《Docs: 增加首次运行的步骤截图》。正文：README 截图展示了 UI，但没展示首次运行流程。在 README.md 的「Try it in 5 minutes」下加 3-4 张带标注的截图或一个简短编号列表：在自己的实例上注册、加第二台设备/浏览器、发出第一条消息。

## 3. Web 端：收到文本消息的「复制」按钮

- 标签：`good first issue`、`web`、`enhancement`
- 为什么：文本/剪贴板发送是核心场景；Web 端一键复制是个小而自洽的 UI 改动。
- Title：`Web: add copy-to-clipboard button on received text messages`
- Body：

```text
Text/clipboard sending is a core use case. Add a copy button on text messages in the web
chat view with a "copied" toast. Acceptance: button works and `npm run lint` passes in web/.
```

中文译文：标题《Web: 收到的文本消息加一键复制按钮》。正文：文本/剪贴板发送是核心场景。在 Web 端聊天视图的文本消息上加一个复制按钮，附「已复制」toast。验收：按钮可用，且 web/ 下 `npm run lint` 通过。

## 4. Web 端：显示本次传输走的路径

- 标签：`good first issue`、`web`、`enhancement`
- 为什么：连接诊断已经知道传输走的是 LAN / 反向拉取 / WebRTC / S3；用一个小徽标呈现出来能强化产品差异点。
- Title：`Web: surface the active transfer path in the UI`
- Body：

```text
The connection diagnostic already knows whether a transfer used LAN / reverse pull /
WebRTC / S3. Add a small badge/label near the transfer indicating the path used.
```

中文译文：标题《Web: 在界面上显示本次传输走的路径》。正文：连接诊断已经知道传输走的是 LAN / 反向拉取 / WebRTC / S3。在传输旁加一个小徽标/标签，标明本次走的路径。

## 5. Backend：启动时校验并说明必需的环境变量

- 标签：`good first issue`、`backend`、`self-hosting`
- 为什么：缺某个环境变量时自托管者会遇到很迷惑的报错；清晰的启动检查能改善首次体验。
- Title：`Backend: validate and document required environment variables on startup`
- Body：

```text
Self-hosters hit confusing failures when an env var is missing. On startup, log a clear,
actionable message naming any missing required variable (e.g. datasource URL, Centrifugo
keys) instead of failing deep in the stack.
```

中文译文：标题《Backend: 启动时校验并说明必需的环境变量》。正文：缺某个环境变量时自托管者会遇到迷惑的报错。启动时输出一条清晰、可操作的信息，点名任何缺失的必需变量（如数据源 URL、Centrifugo 密钥），而不是在调用栈深处才失败。

## 6. i18n：审校 Web 端英文文案

- 标签：`good first issue`、`web`、`i18n`
- 为什么：项目是双语（zh/en）；面向 HN 流量前，英文文案值得母语者过一遍。
- Title：`i18n: audit the English strings in the web client`
- Body：

```text
The project is bilingual (zh/en). Submit a PR fixing awkward or inconsistent English
strings in web/, noting before/after in the description.
```

中文译文：标题《i18n: 审校 Web 端的英文文案》。正文：项目是双语（zh/en）。提交一个 PR 修正 web/ 下别扭或不一致的英文文案，并在描述里写明修改前后。

## 7. 仓库：给只改 Web 的贡献者加 CONTRIBUTING 快速上手

- 标签：`good first issue`、`documentation`
- 为什么：很多贡献者只想动 Web 客户端，不需要完整后端/Flutter 环境。
- Title：`Repo: add a CONTRIBUTING quickstart for web-only contributors`
- Body：

```text
Many contributors only want to touch the web client. Add a short "Web-only setup" note in
CONTRIBUTING.md pointing the web client at the official/your dev API.
```

中文译文：标题《Repo: 给只改 Web 的贡献者加 CONTRIBUTING 快速上手》。正文：很多贡献者只想动 Web 客户端。在 CONTRIBUTING.md 加一段简短的「Web-only setup」，把 Web 客户端指向官方/你自己的开发 API。

## 8. 协议：给英文摘要加上请求/响应示例

- 标签：`good first issue`、`documentation`
- 为什么：[shared/protocol.en.md](../../shared/protocol.en.md) 描述了各端点；给 `/probe`、`/transfer-status`、预签名上传加上具体 curl 示例，方便验证自托管实例。
- Title：`Protocol: add request/response examples to the English summary`
- Body：

```text
shared/protocol.en.md describes the endpoints. Add a short "Examples" section with
copy-pasteable curl commands for /probe, /transfer-status, and a presigned upload.
```

中文译文：标题《Protocol: 给英文摘要加上请求/响应示例》。正文：shared/protocol.en.md 描述了各端点。加一个简短的「Examples」小节，给 /probe、/transfer-status 和预签名上传配上可直接复制的 curl 命令。
