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
