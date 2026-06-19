# FAQ 回复模板

HN 必问问题的预写答案。**中文是问题归类和给你的提示；代码块里的英文是要发出去的回复**，作为素材按评论的具体措辞改写，同一 thread 里别原样重复粘同一段。你下线时，同事可用这些维持 thread 热度。语气：事实、不浮夸、绝不贬低竞品。

---

## 「和 LocalSend 有什么区别？」

提示：承认 LocalSend 在干净局域网下很好，再点出你针对的是它不覆盖的场景。

```text
LocalSend is excellent when every device is on a reachable LAN with the app installed.
ShrimpSend targets the cases it doesn't: asymmetric/one-way connectivity (phone can reach PC
but not vice versa), cross-network sends, resume after a disconnect, and joining from a
browser on a machine where you can't install anything. The tradeoff is more moving parts
(there's a coordinating server for the fallback chain), in exchange for working off the happy
path. If your devices are always on a clean LAN, LocalSend may be all you need.
```

## 「和 Syncthing 有什么区别？」

提示：模型不同——持续同步文件夹 vs 即时发送到指定设备。

```text
Different model. Syncthing continuously syncs folders across devices; it's great for keeping
directories identical. ShrimpSend is for explicit, one-shot-ish sends into a device
conversation — "send this screenshot to my laptop now" rather than "keep these folders in
sync forever." Many people use both.
```

## 「为什么不用 Magic Wormhole / Pairdrop / Snapdrop？」

```text
Those are great for one-off transfers. ShrimpSend optimizes for repeated sends between your
devices that persist in a conversation, plus resume and the cross-network fallback chain. If
you just need to beam one file to someone once, wormhole is hard to beat.
```

## 「AGPL 有没有坑？是不是 open-core？」

提示：明确不是 open-core；自托管自用免费；商业许可只针对 AGPL 无法覆盖的情况。

```text
No open-core split: the code you self-host is the same code that runs the hosted service.
AGPL-3.0 means self-hosting for yourself or your organization is free; if you modify it and
offer it as a network service to third parties, AGPL asks you to share your modifications.
There's a separate commercial license only for orgs that can't comply with that (e.g.
closed-source modified SaaS, OEM/white-label). Details:
https://github.com/shrimpsend/shrimpsend/blob/main/LICENSE-Commercial.md
```

## 「凭什么信你来传我的文件？」

```text
You don't have to — self-host and your files never touch our servers. The code is open and
auditable. On the hosted service, files move via presigned S3 URLs and text bodies are
encrypted at rest. For maximum control, point it at your own S3-compatible storage or run the
whole stack yourself.
```

## 「来自中国——数据主权 / 隐私？」

提示：强调开源可审计、国际站独立集群、自托管数据在自己手里。

```text
The codebase is fully open and the international hosted edition (shrimpsend.com) runs on its
own cluster, separate from the China edition (xiachuan.net). If sovereignty matters to you,
self-host: the stack runs entirely on your own infrastructure and the source is the same as
what we run.
```

## 「加密 / 端到端怎么样？」

提示：诚实说明现状，不要过度宣称 E2E。

```text
Today, text bodies are encrypted at rest on the server and transport is TLS; same-LAN direct
transfers don't traverse our servers at all. Full end-to-end encryption for relayed transfers
isn't there yet — happy to discuss the design in an issue if that's a blocker for you. I'd
rather be precise about what exists than overclaim.
```

## 「收费吗？」

```text
Free for 3 devices. Beyond that there are paid tiers (subscription internationally, one-time
purchase in China) mostly for more devices and hosted upload quota. But if you're here for
the open-source stack, self-hosting removes the limits entirely.
```

## 「能用我自己的 S3 / 存储吗？」

```text
Yes — you can point it at any S3-compatible endpoint instead of the hosted bucket. S3 is the
fallback relay path, not the primary one; LAN/WebRTC are preferred when reachable.
```

## 「给我看看协议 / reverse-pull 怎么工作」

```text
English summary: https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md —
covers HTTP push, reverse pull (with Range-based resume), WebRTC DataChannels, and the S3
multipart path. The short version: reachability is directional, so when the receiver can't
accept a connection, the reachable side pulls instead of the sender pushing.
```

## 「我自托管没跑起来」

提示：这是发帖期间实时修文档的最高杠杆机会，态度要好，引导对方开 issue。

```text
Sorry about that — which step and what error? There's a 5-minute Docker path in the README
and a guide at docs/SELF_HOST.md. If you can open an issue with the command, your OS, and
which service failed (MySQL :3306 / Centrifugo :8000 / backend :9000 / web :3000), I'll fix
the docs or the bug.
```

## 「HarmonyOS？为什么？」

```text
It's a real platform for part of our user base. It's not central to the HN story — the
interesting parts are the transfer protocol and self-hosting. Happy to go deeper on those
instead.
```

## 语气提醒（中文）

- 合理批评立刻承认，并转化为 issue。
- 不说 "revolutionary"、"best"、"simply"。描述行为和取舍。
- 对批评者和夸奖者一样感谢——尖锐的问题是发帖最有价值的收获。
