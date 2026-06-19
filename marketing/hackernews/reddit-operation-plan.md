# Reddit 运营计划

Reddit 适合做 **HN 前置预热 + 自托管用户反馈 + GitHub star 长尾来源**。和 HN 不同，Reddit 是一个个 subreddit 组成的社区，每个社区规则不同；不要同文群发，不要上来就贴链接。先做账号可信度，再分社区投放。

> 双语约定：中文是给你看的执行流程；代码块里的英文是对外可发素材。每段英文后有中文译文，方便你核对含义。

## 目标

1. 在 HN 发帖前 2–3 周，积累 Reddit 账号可信度和英文互动手感。
2. 找到最可能喜欢 ShrimpSend 的用户：自托管、开源工具、多设备重度用户、LocalSend/Syncthing/Magic Wormhole 用户。
3. 收集真实反馈，尤其是 self-host 路径、README、协议解释是否清楚。
4. 为 GitHub 带来稳定长尾：star、issue、self-host 尝试，而不是一次性流量。

## 核心定位

中文理解：

> ShrimpSend 是一个 AGPL 开源、可自托管的多设备文件/文本传输工具。它不是网盘，也不是一次性外链，而是「自己的设备会话」：局域网优先，复杂 NAT / 单向防火墙下反向拉取，大文件断点续传，浏览器可临时加入。

英文对外：

```text
ShrimpSend is an AGPL self-hostable tool for sending text and files between your own devices:
LAN-first, reverse-pull fallback for one-way networks, resume for large files, and a web
client for machines where you can't install anything.
```

中文译文：ShrimpSend 是一个 AGPL、可自托管的工具，用来在你自己的设备之间发送文本和文件：局域网优先，单向网络下有反向拉取兜底，大文件可断点续传，并提供 Web 客户端用于无法安装软件的机器。

## 账号策略

如果你的 Reddit 账号也是老账号但没怎么发过内容，处理方式和 HN 类似：账号年龄有帮助，但**仍要先评论一段时间**。Reddit 更看重具体 subreddit 内的行为记录；有些社区会自动拦截低 karma / 新发言账号。

执行节奏：

| 时间 | 动作 | 目标 |
|---|---|---|
| 第 1 周 | 只评论，不发产品帖 | 让账号在目标社区留下正常活动记录 |
| 第 2 周 | 继续评论，发 1 篇技术/经验帖，不主推产品 | 测试语气，收集反馈 |
| 第 3 周 | 在最相关的 1–2 个 subreddit 发反馈帖 | 小范围验证定位 |
| 第 4 周 | 根据反馈优化 README/FAQ，再决定是否 HN | 把 Reddit 反馈反哺 HN |

## 目标 subreddit

发帖前必须逐个读 rules 和置顶帖。有些社区只允许特定日期/特定 flair 的项目展示。

| 优先级 | Subreddit | 适合内容 | 注意 |
|---|---|---|---|
| P0 | `r/selfhosted` | 自托管反馈帖、部署体验、AGPL 项目展示 | 规则严，必须披露作者身份，先评论再发 |
| P0 | `r/opensource` | 开源项目介绍、寻求贡献者反馈 | 避免商业化口吻 |
| P1 | `r/coolgithubprojects` | GitHub 项目展示 | 更适合直接链 repo |
| P1 | `r/SideProject` | indie maker 故事、冷启动反馈 | 可讲「为什么做」 |
| P1 | `r/webdev` | Web 客户端、WebRTC / realtime 技术讨论 | 不要硬广，只发技术角度 |
| P2 | `r/productivity` | 多设备工作流场景 | 需弱化开源协议，强调日常痛点 |
| P2 | `r/androidapps` / `r/macapps` | 客户端体验反馈 | 先确认是否允许开发者自荐 |
| P2 | `r/DataHoarder` | 大文件、可靠传输、存储兜底 | 谨慎，用户更关心数据控制和限制 |

不建议一开始碰：泛科技大社区、下载/软件推荐大杂烩、规则不清的推广社区。流量看似大，转化和风险都差。

## 评论养号方法

每天 10–15 分钟即可。找 LocalSend、Syncthing、KDE Connect、Magic Wormhole、自托管、NAT、文件传输相关帖子。先认真回答，不贴产品链接。只有当别人明确问「有没有工具」或话题强相关时，才披露并提 ShrimpSend。

披露语：

```text
Disclosure: I'm building ShrimpSend, an open-source tool in this space, so I'm biased.
```

中文译文：披露一下：我在做 ShrimpSend，一个这个领域的开源工具，所以我有立场偏向。

示例评论 1：在 LocalSend / Syncthing 对比帖下

```text
LocalSend and Syncthing solve two different jobs for me. Syncthing is great when I want a
folder to stay in sync. LocalSend is great for a quick LAN transfer. The gap I keep running
into is when the network is asymmetric: one device can reach the other, but not the reverse
direction, or when I need a browser to join from a machine where I can't install anything.
That distinction matters more than I expected.
```

中文译文：LocalSend 和 Syncthing 对我来说解决的是两件不同的事。Syncthing 适合让文件夹保持同步。LocalSend 适合快速局域网传输。我反复遇到的缺口是网络不对称：一台设备能连到另一台，但反方向不行；或者我需要从一台装不了软件的机器上用浏览器加入。这个区别比我原先预期的重要得多。

示例评论 2：在自托管工具帖下

```text
For self-hosted transfer tools, the first-run path matters a lot. If someone can't get from
`git clone` to \"sent my first file\" in about 10 minutes, most of the launch traffic is gone.
The unglamorous docs — ports, env vars, WebSocket auth, where logs live — probably matter
more than the feature list.
```

中文译文：对自托管传输工具来说，首次运行路径非常重要。如果用户不能在大约 10 分钟内从 `git clone` 走到「发出第一个文件」，大多数发帖流量就流失了。那些不性感的文档——端口、环境变量、WebSocket 鉴权、日志在哪——可能比功能列表更重要。

示例评论 3：在 NAT / 网络问题帖下

```text
One practical lesson: treat reachability as directional. \"A can connect to B\" doesn't imply
\"B can connect to A\", even on the same Wi-Fi. Windows firewall, mobile background limits,
guest Wi-Fi isolation, and nested routers all make this surprisingly common.
```

中文译文：一个实际经验：把可达性当作有方向的。「A 能连到 B」并不意味着「B 也能连到 A」，即使在同一个 Wi-Fi 下也是如此。Windows 防火墙、移动端后台限制、访客 Wi-Fi 隔离、嵌套路由都会让这种情况变得很常见。

## 发帖策略

### 第一次发帖：反馈帖，不是发布帖

优先发到 `r/selfhosted` 或 `r/opensource`。标题要像请教，不像广告。

标题候选（英文发布）：

```text
Looking for feedback: self-hostable file transfer between your own devices
```

中文译文：寻求反馈：在你自己的设备之间传文件的可自托管工具。

正文模板（英文发布）：

```text
Hi — I'm building ShrimpSend, an AGPL self-hostable tool for sending text and files between
your own devices.

The problem I'm trying to solve is the awkward middle ground between LocalSend, Syncthing,
cloud drives, and \"send myself a link\" workflows:

- repeated sends between my own devices, not public file sharing
- LAN-first when devices are nearby
- reverse-pull fallback when the network is one-way (for example, phone can reach PC but PC
  can't reach phone)
- resume for large native-client transfers
- a web client for machines where I can't install anything

Repo: https://github.com/shrimpsend/shrimpsend
Protocol summary: https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md

I'm not looking for upvotes; I'm looking for harsh feedback on the self-host path and the
README. If you have time to try it, where does the setup break or feel confusing?
```

中文译文：你好，我在做 ShrimpSend，一个 AGPL、可自托管的工具，用来在你自己的设备之间发送文本和文件。我想解决的是 LocalSend、Syncthing、网盘和「给自己发链接」之间那块尴尬区域：在自己的设备间重复发送，而不是公开分享；设备靠近时局域网优先；网络单向时用反向拉取兜底（例如手机能连 PC，但 PC 连不回手机）；原生客户端大文件断点续传；无法安装软件的机器可用 Web 客户端。仓库和协议链接如上。我不是来求赞的，而是想要对 self-host 路径和 README 的尖锐反馈。如果你有时间试一下，安装哪里会断、哪里让人困惑？

### 第二次发帖：技术帖

在第一次反馈帖后至少间隔 5–7 天。发到 `r/webdev`、`r/selfhosted` 或相关技术社区，主题围绕 reverse-pull，不要主推产品。

标题候选：

```text
Why I added reverse-pull to a self-hosted file transfer tool
```

中文译文：为什么我给一个自托管文件传输工具加了反向拉取。

正文可以复用 [blog-reverse-pull.md](blog-reverse-pull.md)，但 Reddit 上建议压缩到 60–70%，把代码和链接放少一点。

### 第三次发帖：正式展示帖

只有当前两轮没有被社区反感、且 self-host 文档已修顺，再发正式展示。

标题候选：

```text
I built an AGPL self-hostable alternative for sending files between my own devices
```

中文译文：我做了一个 AGPL、可自托管的工具，用来在我自己的设备之间传文件。

正文要短：痛点 3 行、差异点 4 条、repo 链接、请大家试 self-host。不要贴定价，不要贴 App Store，不要营销词。

## 每个平台的语气

| 场景 | 该说 | 不该说 |
|---|---|---|
| `r/selfhosted` | 可自托管、AGPL、S3 可自配、部署文档求反馈 | 官方云、订阅、增长目标 |
| `r/opensource` | 许可证、贡献入口、good first issue、协议文档 | 商业许可放太前 |
| `r/SideProject` | 为什么做、做了多久、遇到的技术坑 | 像广告落地页一样写 |
| `r/productivity` | 手机/电脑/浏览器之间少摩擦 | 太多协议细节 |
| 技术社区 | reverse-pull、NAT、WebRTC、Centrifugo | 「快来下载」 |

## 时间线（配合 HN）

| 周 | Reddit 动作 | HN 动作 |
|---|---|---|
| 第 1 周 | 每天 1–2 条评论，不贴链接 | HN 也开始评论养号 |
| 第 2 周 | 发第一篇反馈帖，收集 self-host 问题 | 修 README / self-host 文档 |
| 第 3 周 | 发技术帖或继续评论 | HN 预热技术文 |
| 第 4 周 | 不在 Reddit 大规模发帖，避免和 HN 抢精力 | Show HN |
| HN 后 D+3 | 把 HN 常见问题整理后，可回 Reddit 发 follow-up | 沉淀 FAQ |

## 成功指标

| 指标 | 及格 | 达标 |
|---|---:|---:|
| 有质量评论 | 10 条 | 20+ 条 |
| Reddit 带来的 GitHub star | 20–50 | 100+ |
| self-host 反馈 issue | 3 条 | 8+ 条 |
| 被删除/被喷推广 | 0 次 | 0 次 |
| 有人主动比较 LocalSend/Syncthing | 有 | 多人讨论 |

## 风险与处理

- **被认为是 self-promo**：标题用「Looking for feedback」，正文先写问题和取舍，明确披露作者身份。
- **subreddit 删帖**：不要争辩；私信 mod 礼貌询问是否可按规则改发。
- **被质疑 AGPL/商业许可**：直接用 [faq-responses.md](faq-responses.md) 的 AGPL 模板。
- **被质疑中国背景/隐私**：强调开源、自托管、国际站独立；不要情绪化。
- **一次发太多社区**：不要同一天多社区群发；每帖间隔至少 3–5 天，根据反馈改下一帖。

## 每次发帖前 checklist

- [ ] 已读该 subreddit rules、置顶帖、flair 要求。
- [ ] 标题不是广告语，而是反馈/技术/经验角度。
- [ ] 正文前 5 行已经说明「我是谁、做什么、求什么反馈」。
- [ ] 披露自己是作者。
- [ ] 只放 1–2 个链接，优先 repo 和协议/README。
- [ ] 不提定价，除非被问到。
- [ ] 发帖后 2 小时内能持续回复。
- [ ] 把 Reddit 反馈同步到 GitHub issue 或 README TODO。

