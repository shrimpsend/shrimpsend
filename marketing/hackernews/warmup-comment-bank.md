# HN 养号评论库

用于发帖前 2–3 周。目的：在 HN 上积累一点真实的发言记录，让你发帖当天不是全新账号；同时摸清这个受众怎么聊传输 / NAT / 自托管话题。

## 规则（别跳过）

- 先提供真实价值。先回答问题或给出具体见解；只在真正相关时提到 ShrimpSend，并披露你是作者。
- 绝不刷水军：不用马甲号、不喊人点赞、不发没干货的纯链接。HN 能识别并重罚，且不可恢复。
- 每周 2–3 条有实质内容的评论足矣。质量优先于数量。
- thread 若跟你的领域无关，不要硬塞产品。

## 去哪里找

用 HN 搜索（Algolia：https://hn.algolia.com）找正在活跃的、关于以下话题的 thread 去评论：

- LocalSend、Syncthing、Snapdrop/Pairdrop、Magic Wormhole、KDE Connect
- NAT 穿透、打洞、WebRTC 数据通道、STUN/TURN
- 自托管文件传输 / 「在自己的设备间传文件」
- Windows 防火墙 / 单向连通的吐槽

## 披露语（复用）

英文，直接用：

```text
Disclosure: I work on ShrimpSend, an open-source tool in this space, so I'm biased.
```

中文译文：披露一下：我在做 ShrimpSend，一个这个领域的开源工具，所以我有立场偏向。

## 示例评论（英文，按情况改写，切勿原样照抄）

### 在 NAT / 连通性 thread 下

```text
One thing that surprised me building a device-to-device transfer tool: reachability is
directional. On the same Wi-Fi, a phone can usually POST to a desktop, but the desktop
often can't connect back (Windows firewall, mobile listener restrictions, or the AP
isolating clients). Retrying the same direction just times out. Flipping it — let the
reachable side pull instead of insisting the sender push — recovers a surprising fraction
of "same network but won't connect" cases before you even reach for WebRTC.
(Disclosure: I work on a tool that does this.)
```

中文译文：做设备间传输工具时让我意外的一点是：可达性是有方向的。同一个 Wi-Fi 下，手机通常能 POST 给台式机，但台式机往往连不回来（Windows 防火墙、移动端监听限制，或 AP 隔离了客户端）。一味重试同一个方向只会超时。把它翻转过来——让可达的一方去拉取，而不是非要发送方推送——能在你动用 WebRTC 之前救回相当一部分「同网却连不上」的情况。（披露：我在做一个这么干的工具。）

### 在 LocalSend / 局域网传输 thread 下

```text
LocalSend is great when every device is on a reachable LAN with the app installed. The
cases it doesn't target are cross-network sends, one-way firewalls, resume after a drop,
and joining from a browser on a machine where you can't install anything. Those are exactly
the gaps that pushed me to build something with a server-coordinated fallback chain.
Different tradeoff — more moving parts, but it keeps working off the happy path.
(Disclosure: biased, I build one of these.)
```

中文译文：LocalSend 在每台设备都装了应用、且局域网可达时很棒。它没瞄准的场景是：跨网发送、单向防火墙、断线续传，以及从一台装不了软件的机器上用浏览器加入。正是这些缺口促使我做了一个带服务端协调兜底链路的东西。取舍不同——环节更多，但在非理想路径下也能继续工作。（披露：我有立场，我就在做这类工具之一。）

### 在自托管 thread 下

```text
If you self-host this kind of thing, the detail that bit me was Centrifugo/WebSocket auth
config — easy to get a backend up and then spend an hour on why the realtime channel won't
connect. Worth documenting the required env vars with a startup validation check. Happy to
share what we ended up with.
```

中文译文：如果你自托管这类东西，让我栽过跟头的细节是 Centrifugo/WebSocket 的鉴权配置——很容易把后端跑起来，然后花一个小时排查实时频道为什么连不上。值得把必需的环境变量写进文档，并加一个启动时校验。乐意分享我们最后的做法。

## 记录在案

用一张小表记录，避免过度发帖或重复自己：

```
日期 | thread (url) | 话题 | 是否链了产品 (是/否) | 备注
```
