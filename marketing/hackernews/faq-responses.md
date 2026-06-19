# FAQ 回复模板

HN 必问问题的预写答案。**中文是问题归类和给你的提示；代码块里的英文是要发出去的回复**，作为素材按评论的具体措辞改写，同一 thread 里别原样重复粘同一段。每段英文后附**中文译文**，仅供你核对含义，不要发出去。语气：事实、不浮夸、绝不贬低竞品。

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

中文译文：LocalSend 在每台设备都装了应用、且处于可达局域网时非常好用。ShrimpSend 针对的是它不覆盖的场景：不对称/单向连通（手机能连到 PC，反之不行）、跨网发送、断线续传，以及从一台装不了软件的机器上用浏览器加入。代价是多了一些环节（兜底链路需要一个协调服务），换来的是在「非理想路径」下也能工作。如果你的设备一直在干净局域网里，LocalSend 可能就够了。

## 「和 Syncthing 有什么区别？」

提示：模型不同——持续同步文件夹 vs 即时发送到指定设备。

```text
Different model. Syncthing continuously syncs folders across devices; it's great for keeping
directories identical. ShrimpSend is for explicit, one-shot-ish sends into a device
conversation — "send this screenshot to my laptop now" rather than "keep these folders in
sync forever." Many people use both.
```

中文译文：模型不同。Syncthing 在设备间持续同步文件夹，擅长让目录保持一致。ShrimpSend 是把内容明确地、一次性地发进某个设备会话——「现在把这张截图发到我的笔记本」，而不是「让这些文件夹永远保持同步」。很多人两个都用。

## 「为什么不用 Magic Wormhole / Pairdrop / Snapdrop？」

```text
Those are great for one-off transfers. ShrimpSend optimizes for repeated sends between your
devices that persist in a conversation, plus resume and the cross-network fallback chain. If
you just need to beam one file to someone once, wormhole is hard to beat.
```

中文译文：它们很适合一次性传输。ShrimpSend 优化的是在你自己设备之间、留存于会话里的重复发送，外加断点续传和跨网兜底链路。如果你只是想给别人一次性传一个文件，wormhole 很难被超越。

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

中文译文：没有 open-core 的切割：你自托管的代码就是跑托管服务的同一份代码。AGPL-3.0 意味着自用或组织内自托管免费；如果你修改它并以网络服务形式提供给第三方，AGPL 要求你公开你的修改。只有无法遵守这一点的组织（例如闭源改造后的 SaaS、OEM/白标）才需要单独的商业许可。详情：https://github.com/shrimpsend/shrimpsend/blob/main/LICENSE-Commercial.md

## 「凭什么信你来传我的文件？」

```text
You don't have to — self-host and your files never touch our servers. The code is open and
auditable. On the hosted service, files move via presigned S3 URLs and text bodies are
encrypted at rest. For maximum control, point it at your own S3-compatible storage or run the
whole stack yourself.
```

中文译文：你不必信——自托管的话，你的文件根本不碰我们的服务器。代码开源、可审计。在托管服务上，文件通过 S3 预签名 URL 传输，文本正文静态加密。想要最大控制权，就指向你自己的 S3 兼容存储，或自己跑整套栈。

## 「来自中国——数据主权 / 隐私？」

提示：强调开源可审计、国际站独立集群、自托管数据在自己手里。

```text
The codebase is fully open and the international hosted edition (shrimpsend.com) runs on its
own cluster, separate from the China edition (xiachuan.net). If sovereignty matters to you,
self-host: the stack runs entirely on your own infrastructure and the source is the same as
what we run.
```

中文译文：代码完全开源，国际托管版（shrimpsend.com）跑在独立集群上，与国内版（xiachuan.net）分开。如果你在意数据主权，就自托管：整套栈完全运行在你自己的基础设施上，源码与我们运行的是同一份。

## 「加密 / 端到端怎么样？」

提示：诚实说明现状，不要过度宣称 E2E。

```text
Today, text bodies are encrypted at rest on the server and transport is TLS; same-LAN direct
transfers don't traverse our servers at all. Full end-to-end encryption for relayed transfers
isn't there yet — happy to discuss the design in an issue if that's a blocker for you. I'd
rather be precise about what exists than overclaim.
```

中文译文：目前文本正文在服务端静态加密，传输走 TLS；同网局域网直传根本不经过我们的服务器。中继传输的完整端到端加密还没有——如果这是你的硬阻塞，欢迎在 issue 里讨论设计方案。我宁愿精确说明现有能力，也不愿过度宣称。

## 「收费吗？」

```text
Free for 3 devices. Beyond that there are paid tiers (subscription internationally, one-time
purchase in China) mostly for more devices and hosted upload quota. But if you're here for
the open-source stack, self-hosting removes the limits entirely.
```

中文译文：3 台设备免费。再多就有付费档（国际订阅制，国内买断制），主要是为更多设备数和托管上传配额。但如果你是为开源栈而来，自托管能完全去掉这些限制。

## 「能用我自己的 S3 / 存储吗？」

```text
Yes — you can point it at any S3-compatible endpoint instead of the hosted bucket. S3 is the
fallback relay path, not the primary one; LAN/WebRTC are preferred when reachable.
```

中文译文：可以——你可以指向任意 S3 兼容端点，替代托管桶。S3 是兜底中继路径，不是主路径；可达时优先走局域网/WebRTC。

## 「给我看看协议 / reverse-pull 怎么工作」

```text
English summary: https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md —
covers HTTP push, reverse pull (with Range-based resume), WebRTC DataChannels, and the S3
multipart path. The short version: reachability is directional, so when the receiver can't
accept a connection, the reachable side pulls instead of the sender pushing.
```

中文译文：英文摘要：https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md —— 覆盖 HTTP 直推、反向拉取（基于 Range 续传）、WebRTC 数据通道，以及 S3 分片路径。一句话版本：可达性是有方向的，所以当接收方无法接受连接时，由可达的一方拉取，而不是发送方推送。

## 「我自托管没跑起来」

提示：这是发帖期间实时修文档的最高杠杆机会，态度要好，引导对方开 issue。

```text
Sorry about that — which step and what error? There's a 5-minute Docker path in the README
and a guide at docs/SELF_HOST.md. If you can open an issue with the command, your OS, and
which service failed (MySQL :3306 / Centrifugo :8000 / backend :9000 / web :3000), I'll fix
the docs or the bug.
```

中文译文：抱歉——卡在哪一步、什么报错？README 里有 5 分钟 Docker 路径，docs/SELF_HOST.md 有指南。如果你能开个 issue，附上命令、你的系统，以及是哪个服务失败了（MySQL :3306 / Centrifugo :8000 / backend :9000 / web :3000），我会修文档或修 bug。

## 「HarmonyOS？为什么？」

```text
It's a real platform for part of our user base. It's not central to the HN story — the
interesting parts are the transfer protocol and self-hosting. Happy to go deeper on those
instead.
```

中文译文：对我们的一部分用户来说它是真实存在的平台。它不是 HN 故事的重点——有意思的是传输协议和自托管。我更乐意在这两点上深入聊。

## 语气提醒（中文）

- 合理批评立刻承认，并转化为 issue。
- 不说 "revolutionary"、"best"、"simply"。描述行为和取舍。
- 对批评者和夸奖者一样感谢——尖锐的问题是发帖最有价值的收获。
