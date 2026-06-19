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

### 在 LocalSend / 局域网传输 thread 下

```text
LocalSend is great when every device is on a reachable LAN with the app installed. The
cases it doesn't target are cross-network sends, one-way firewalls, resume after a drop,
and joining from a browser on a machine where you can't install anything. Those are exactly
the gaps that pushed me to build something with a server-coordinated fallback chain.
Different tradeoff — more moving parts, but it keeps working off the happy path.
(Disclosure: biased, I build one of these.)
```

### 在自托管 thread 下

```text
If you self-host this kind of thing, the detail that bit me was Centrifugo/WebSocket auth
config — easy to get a backend up and then spend an hour on why the realtime channel won't
connect. Worth documenting the required env vars with a startup validation check. Happy to
share what we ended up with.
```

## 记录在案

用一张小表记录，避免过度发帖或重复自己：

```
日期 | thread (url) | 话题 | 是否链了产品 (是/否) | 备注
```
