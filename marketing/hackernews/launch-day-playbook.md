# Show HN 发帖日剧本

发帖本身要用的全部内容。针对约束做了优化：发帖当天你只能用英文互动约 2–3 小时。

## 何时发

| 北京时间 | 美西时间 | 原因 |
|---|---|---|
| 周二或周三 21:00–22:00 | 约 6:00–7:00 AM PT | 美国早晨刷 HN 高峰；你可互动到约 24:00 北京时间 |

避免：周一（帖多）、周五下午 PT、美国节假日。

## 标题（发帖前定一个）

下面是要直接发出去的英文标题，三选一：

```text
1. Show HN: ShrimpSend – AGPL cross-device file transfer with LAN-first and reverse-pull fallback
2. Show HN: Open-source file transfer between your devices (resume, WebRTC, self-hostable)
3. Show HN: When HTTP push fails, pull instead – AGPL device-to-device transfer
```

中文译文（仅供理解，发布用英文）：

1. Show HN: ShrimpSend —— AGPL 开源的跨设备文件传输，局域网优先、反向拉取兜底
2. Show HN: 在你自己的设备之间开源传文件（断点续传、WebRTC、可自托管）
3. Show HN: 当 HTTP 推送失败时，改为拉取 —— AGPL 设备间传输

原则：事实陈述、带 `Show HN:` 前缀、至少出现 `AGPL` / `self-hostable` 之一，不用浮夸词。

## 链接目标

- **提交 URL**：`https://github.com/shrimpsend/shrimpsend`（目标是 GitHub 关注度，所以链仓库而不是落地页）。
- 首评里再补：`https://shrimpsend.com`（试用）和协议文档（技术深度）。

## 逐分钟流程

| 时刻 | 动作 |
|---|---|
| T-24h | 跑完下方「发帖前 checklist」。 |
| T+0 | 用选定标题提交 Show HN，URL = 仓库地址。 |
| T+1 分钟 | 粘贴 [maker-comment.md](maker-comment.md) 里的英文首评。 |
| T+0 ~ T+3h | 每隔几分钟刷 HN + GitHub 通知。按下方优先级回复。 |
| 下线前 10 分钟 | 发一句英文：`Heading offline for a bit — I'll keep replying in GitHub Discussions.`（中文意思：我先下线一会儿，会继续在 GitHub Discussions 回复） |
| 下线后 | 有同事就用 [faq-responses.md](faq-responses.md) 接力；否则回复转到 Discussions 继续。 |

**不要**让任何人帮你点赞，**不要**用全新账号发帖——用按 [warmup-comment-bank.md](warmup-comment-bank.md) 养过的账号。

## 回复优先级（你在线的 2–3 小时）

1. **技术质疑**（协议、安全、AGPL）→ 详细回答 + 链文档。这些定调整个 thread。
2. **「和 X 比怎么样」** → 用 [faq-responses.md](faq-responses.md)，绝不贬低竞品。
3. **self-host 卡住** → 实时修文档/bug，回复里贴上修复或 issue 链接。对 GitHub 目标杠杆最高。
4. **功能请求** → `Good idea — filed as #NNN.` 把评论转成被跟踪的 issue。
5. **纯夸奖** → 简短感谢，引导 star / 试用。

## 发帖前 checklist（T-24h）

- [ ] README 顶部有 5 分钟 Docker 上手，最好有一段简短 demo GIF。
- [ ] demo GIF/截图已就绪（录制：选设备 → 拖文件 → 连接诊断显示路径）。没录好就不放，别放破图。
- [ ] GitHub Release 已发（见 [../../docs/RELEASE_NOTES_v1.4.9.md](../../docs/RELEASE_NOTES_v1.4.9.md)）。
- [ ] 至少 5 个 `good first issue` 已发（见 [good-first-issues.md](good-first-issues.md)）。
- [ ] GitHub Discussions 已开启。
- [ ] Issue/PR 模板已上线（`.github/`）。
- [ ] 至少 3 位测试者在干净机器上跑到「发出第一条消息」（见 [self-host-dry-run.md](self-host-dry-run.md)）。
- [ ] shrimpsend.com 注册/下载链路端到端可用。
- [ ] 英文首评 + FAQ 已定稿。
- [ ] 日历已排：21:00 发帖，21:05 首评，高频回复到约 24:00 北京时间。
- [ ]（可选）找一位英文流利的同事，在你下线后接力约 2 小时。

## 不要做的事

- 不买 upvote、不刷票、不用小号。HN 能查出来，惩罚是永久的。
- 不要开头就放定价或 App Store 链接——HN 要技术；定价被问到时放进 FAQ。
- 不要防御性争论。承认合理观点并转化为 issue。
