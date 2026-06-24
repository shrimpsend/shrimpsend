# 技术预热文：反向拉取（reverse-pull）

**用途（中文）**：预热阶段用的技术文章。在 Show HN 前 1–2 周发到 GitHub Discussions 或技术博客（dev.to 等），然后在 maker 首评里引用。它是一篇独立的技术故事，**不是产品软广**，请保持这个调性。

**下面代码块里是要发出去的英文正文**，可直接复制。中文标题《Why reverse-pull beats retrying HTTP push on asymmetric NAT》仅供你理解，发表时用英文标题。

---

英文正文（直接发布）：

```markdown
# Why reverse-pull beats retrying HTTP push on asymmetric NAT

Most "send a file to my other device" tools assume that if two machines are on the same
network, either one can open a connection to the other. On real networks, that assumption is
wrong often enough to matter.

## The asymmetry

Put an Android phone and a Windows desktop on the same Wi-Fi. The phone can usually open a TCP
connection to the desktop and POST a file. The reverse — the desktop connecting to the phone —
frequently fails. The Windows firewall blocks inbound connections by default, mobile OSes
aggressively restrict background listeners, and "the same Wi-Fi" may actually be two subnets
bridged by a router that does not allow client-to-client traffic.

So reachability is directional. `A -> B` working tells you nothing about `B -> A`.

A naive transfer tool picks a direction (say, sender connects to receiver), and when that
fails it retries, backs off, and eventually gives up with a timeout. The user sees "transfer
failed" even though a perfectly good path existed — just in the other direction.

## Reverse pull

The fix is to stop insisting on who connects to whom. Separate two things:

1. Which device has the bytes (the logical sender).
2. Which device can accept an inbound connection right now (the reachable side).

These do not have to be the same device.

After both devices are signed in, the server coordinates a quick reachability probe in both
directions. Then:

- If the receiver is reachable, the sender does a normal HTTP push (`POST /transfer`).
- If the receiver is not reachable but the sender is, the protocol flips: the sender exposes
  the file at `GET /download?offerId=...`, and the receiver pulls it. With `Range` requests,
  the pull resumes after a drop instead of restarting.

The bytes still flow from logical sender to logical receiver. Only the direction of the TCP
connection changed — and that is the one thing the network actually cares about.

## Why not just use WebRTC for everything?

WebRTC with ICE handles a lot of NAT traversal and is the next fallback in the chain. But
establishing a peer connection has setup cost and failure modes of its own, and on a plain LAN
a direct HTTP transfer is simpler and faster. Reverse pull is a cheap win for the very common
case where one HTTP direction is open and the other is not, before paying for WebRTC
negotiation or relaying through S3.

The full path order ends up being: HTTP direct push, HTTP reverse pull, WebRTC peer-to-peer,
then S3-compatible relay as the last resort. Each step is only reached when the cheaper one
cannot connect.

## Takeaways

- Treat reachability as directional. Probe both ways.
- Decouple "who has the data" from "who can accept a connection."
- Reverse pull turns a large class of "same network but won't connect" failures into
  successful transfers without WebRTC or a relay.

The protocol details are documented at
https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md. ShrimpSend is
AGPL-3.0 and self-hostable if you want to poke at the implementation.
```

---

## 中文对照（仅供理解，发布用英文）

> # 在不对称 NAT 下，为什么反向拉取胜过反复重试 HTTP 推送
>
> 多数「把文件发到我的另一台设备」的工具都假设：只要两台机器在同一网络，任意一方都能向另一方发起连接。但在真实网络里，这个假设错得够频繁，足以造成麻烦。
>
> ## 这种不对称
>
> 把一台安卓手机和一台 Windows 台式机放进同一个 Wi-Fi。手机通常能向台式机发起 TCP 连接并 POST 一个文件。反过来——台式机连手机——却经常失败。Windows 防火墙默认拦截入站连接，移动系统会激进地限制后台监听，而「同一个 Wi-Fi」可能其实是被一台不允许客户端互通的路由器桥接的两个子网。
>
> 所以可达性是有方向的。`A -> B` 通，并不能说明 `B -> A` 也通。
>
> 一个天真的传输工具会选定一个方向（比如发送方连接接收方），失败后就重试、退避，最终超时放弃。用户看到「传输失败」，尽管明明存在一条好路径——只是在另一个方向上。
>
> ## 反向拉取
>
> 解法是别再纠结于「谁连谁」。把两件事分开：
>
> 1. 哪台设备有数据（逻辑上的发送方）。
> 2. 哪台设备此刻能接受入站连接（可达的一方）。
>
> 这两者不必是同一台设备。
>
> 两台设备登录后，服务端在两个方向上协调一次快速的可达性探测。然后：
>
> - 如果接收方可达，发送方就做普通的 HTTP 推送（`POST /transfer`）。
> - 如果接收方不可达但发送方可达，协议就翻转：发送方在 `GET /download?offerId=...` 暴露文件，由接收方拉取。配合 `Range` 请求，拉取在断线后能续传而不是重来。
>
> 字节依然是从逻辑发送方流向逻辑接收方。变的只是 TCP 连接的方向——而这恰恰是网络真正在意的那件事。
>
> ## 为什么不干脆全用 WebRTC？
>
> 带 ICE 的 WebRTC 能处理大量 NAT 穿透，也是链路里的下一档兜底。但建立对等连接本身有建连成本和自己的失败模式，而在普通局域网上，直接的 HTTP 传输更简单也更快。对于「一个 HTTP 方向开着、另一个不开」这种极常见的情况，反向拉取是个便宜的胜利，无需先付出 WebRTC 协商或 S3 中继的代价。
>
> 完整的路径顺序最终是：HTTP 直推、HTTP 反向拉取、WebRTC 点对点，最后才是 S3 兼容中继兜底。只有更便宜的一档连不上时，才会进入下一档。
>
> ## 要点
>
> - 把可达性当作有方向的。两个方向都探测。
> - 把「谁有数据」和「谁能接受连接」解耦。
> - 反向拉取能把一大类「同网却连不上」的失败，变成无需 WebRTC 或中继的成功传输。
>
> 协议细节见 https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md 。ShrimpSend 是 AGPL-3.0、可自托管的，想研究实现可以去翻。
