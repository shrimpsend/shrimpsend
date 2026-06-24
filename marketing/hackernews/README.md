# Hacker News 冷启动执行包

ShrimpSend Show HN 发帖的全套执行资产。**目标**：GitHub 关注度（star、issue、fork、自托管尝试）。**约束**：发帖日 maker 只能用英文互动约 2–3 小时，所以策略靠「超长英文首评 + 预写 FAQ + GitHub Discussions」在你下线后继续答疑。

> 双语约定：本执行包里**给你看的指导、说明、清单都是中文**；**真正要发到 HN / GitHub 的英文文案以代码块或引用形式保留英文**（HN 受众读英文，直接粘贴即可）。
>
> HN 受众用国际站 [shrimpsend.com](https://shrimpsend.com)，不要主动提国内版，除非被问到。

## 一句话定位

中文（给你理解）：

> AGPL 开源的多设备文件传输：局域网优先，复杂 NAT / 单向防火墙下自动反向拉取，大文件断点续传，浏览器可临时加入设备会话。

英文（对外用，标题/首评里直接用）：

> AGPL open-source cross-device file transfer: LAN-first, automatic reverse-pull across NAT and one-way firewalls, resume for large files, and a browser can temporarily join a device conversation.

在 HN 用户心智里：你不是「又一个网盘」，而是 **LocalSend 的跨网升级版 + 可自托管的私人设备会话**。

## 文件清单

| 文件 | 用途 |
|---|---|
| [launch-day-playbook.md](launch-day-playbook.md) | 发帖日剧本：时间、标题、链接、逐分钟流程、回复优先级、T-24h checklist |
| [maker-comment.md](maker-comment.md) | 发帖后 60 秒内粘贴的英文首评 |
| [faq-responses.md](faq-responses.md) | HN 高频质疑的英文回复模板 |
| [good-first-issues.md](good-first-issues.md) | 8 个可直接发布的贡献者 issue（英文文案） |
| [self-host-dry-run.md](self-host-dry-run.md) | 发帖前 self-host 实测流程，防止当天翻车 |
| [warmup-comment-bank.md](warmup-comment-bank.md) | 发帖前 2–3 周的 HN 养号评论指引 |
| [reddit-operation-plan.md](reddit-operation-plan.md) | Reddit 运营计划：账号预热、subreddit 策略、发帖模板、反馈回流 |
| [blog-reverse-pull.md](blog-reverse-pull.md) | 围绕差异化的技术预热文（英文正文） |
| [post-launch-followup.md](post-launch-followup.md) | D+0 到 D+7 跟进、第二轮内容、指标 |

## 随这套资产一起改的仓库内容

- [README](../../README.md#try-it-in-5-minutes)：5 分钟 Docker 上手 + 英文协议链接。
- [shared/protocol.en.md](../../shared/protocol.en.md)：英文协议摘要（技术可信度锚点）。
- [docs/RELEASE_NOTES_v1.4.9.md](../../docs/RELEASE_NOTES_v1.4.9.md)：Release 草稿。
- `.github/`：Issue 模板（bug / feature / self-host）+ PR 模板。

## 时间线

1. **第 1–2 周** — GitHub「可被 star」打磨：README/GIF、5 分钟试用、英文协议、good first issues、Release、模板。
2. **第 2–3 周** — 预热：HN 有机评论、Reddit 评论/反馈帖、reverse-pull 技术文、self-host 实测。
3. **第 4 周** — 周二/周三北京时间 21:00 发 Show HN，Reddit 暂停大规模发帖，把精力留给 HN 2–3 小时高频回复。
4. **D+0 到 D+7** — 答疑、沉淀 FAQ、快速响应 issue、评估、规划第二轮。

## 红线（务必遵守）

不买 upvote、不组织刷票、不用小号顶帖——HN 反作弊极严，一次翻车永久伤信誉。开头讲技术而非定价。对合理批评要承认并转化为 issue。
