# Maker 首评（发帖后约 60 秒内粘贴）

发帖后立刻把这条作为 thread 的第一条评论贴上去。在你只能在线 2–3 小时的情况下，它承担主要工作：说清这是什么、为什么做、和别人有何不同，并回答 HN 必问的问题，让你下线后大家也能自助找到答案。

**使用说明（中文）：**

- 把「为什么我要做」那段改成你自己的口吻，别像新闻稿。
- 目标长度约 900–1100 词。
- 下面代码块里的就是**要直接发出去的英文正文**，可整段粘贴后再微调。

---

```text
Hi HN — I'm the maker of ShrimpSend, an AGPL-3.0 tool for sending text and files between
your own devices. Repo: https://github.com/shrimpsend/shrimpsend

Why I built it. I constantly move small things between my phone, laptop, and a locked-down
work PC: a screenshot to annotate, an installer to hand to the machine next to me, a command
I copied in a browser that I want on my phone. The usual options all felt wrong for this.
Cloud drives and "upload, get a link, send the link to myself" are heavy for a 200 KB
screenshot. LocalSend is great on a clean LAN, but it falls apart the moment the network is
asymmetric — and in my experience that's most of the time.

The core idea: device conversations, not links. You don't create a public share link. You
pick one of your devices and send into that conversation — text, clipboard snippets, images,
an installer, a video. Repeated sends feel natural because they all land in the same place,
and a browser can temporarily join the conversation on a machine where you can't install
anything.

What's actually different (vs LocalSend / AirDrop-style tools):

- Reachability is directional. On the same Wi-Fi a phone can usually POST to a desktop, but
  the desktop often can't connect back (Windows firewall, mobile listener limits, AP client
  isolation). When direct push fails, the server coordinates a probe and the reachable side
  does a reverse pull instead of giving up. This recovers a lot of "same network but won't
  connect" cases before paying for WebRTC.
- Resume for large native-client transfers — continue from the interrupted offset instead of
  restarting at 0%.
- A fallback chain, cheapest path first: HTTP direct push on the LAN -> HTTP reverse pull ->
  WebRTC P2P -> S3-compatible relay. Each step is only reached when the cheaper one can't
  connect.
- Web client so a guest/work machine can receive without installing anything.

Protocol write-up (English):
https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md

Stack. Spring Boot (Java 17) + MySQL for the API, Centrifugo for realtime (WebSocket, pushes
updates to all your signed-in devices), Next.js for the web client, Flutter for
iOS/Android/macOS/Windows/Linux, plus a HarmonyOS client. The whole thing is self-hostable —
there's a 5-minute Docker path in the README.

License. AGPL-3.0-or-later. Self-hosting for yourself or your org is free and unrestricted
under AGPL. There's a separate commercial license only for the cases AGPL doesn't cover (e.g.
shipping a closed-source modified network service). I'm not trying to do an open-core
bait-and-switch — the code you self-host is the same code that runs the hosted service.

Privacy. When text is synced through the server, the message body is encrypted at rest;
metadata (type, timestamp, conversation id) stays readable so sync works, and there's no
server-side search over message bodies. Files move via presigned S3 URLs. If you self-host,
all of it is on your own infrastructure.

Honest limitations:

- The full experience needs a native client; the web client is intentionally limited by what
  browsers allow.
- Some enhanced paths (reverse pull, cross-network) require sign-in, because the server has to
  coordinate the probe. Pure same-LAN native transfers can work without an account.
- There's an official hosted edition (shrimpsend.com international; a separate China edition),
  but you don't need it — self-host and you never touch our servers.
- It's a young project; rough edges exist and I'd genuinely like to hear where it breaks for
  you.

What would help most: try the self-host path and tell me where the docs fail you, open
issues, and let me know whether reverse-pull is as useful for your setup as it is for mine.
There are some `good first issue`s tagged if you want to poke at the code.

I'll be around to answer questions for the next few hours. After that I'll keep replying in
GitHub Discussions (https://github.com/shrimpsend/shrimpsend/discussions), so nothing gets
dropped while I'm offline. Thanks for taking a look.
```

---

## 中文对照（仅供理解，不发布）

> 大家好——我是 ShrimpSend 的作者，这是一个 AGPL-3.0 的工具，用来在你自己的设备之间发送文本和文件。仓库：https://github.com/shrimpsend/shrimpsend
>
> **为什么做。** 我经常要在手机、笔记本和一台被严格管控的公司电脑之间倒腾小东西：一张要标注的截图、一个要递给旁边机器的安装包、一段在浏览器里复制、想出现在手机上的命令。常见方案对这种需求都别扭。网盘和「上传、拿链接、把链接发给自己」对一张 200 KB 的截图太重。LocalSend 在干净局域网下很好，但网络一旦不对称就崩——而以我的经验，多数时候都不对称。
>
> **核心思路：设备会话，而不是链接。** 你不创建公开分享链接，而是选中你的一台设备，把内容发进那个会话——文本、剪贴板片段、图片、安装包、视频。重复发送很自然，因为都落在同一个地方；在你装不了软件的机器上，浏览器也能临时加入会话。
>
> **真正的不同之处（对比 LocalSend / AirDrop 类工具）：**
>
> - 可达性是有方向的。同一个 Wi-Fi 下，手机通常能 POST 给台式机，但台式机往往连不回来（Windows 防火墙、移动端后台监听限制、AP 客户端隔离）。当直推失败时，服务端协调一次探测，由可达的一方做**反向拉取**，而不是直接放弃。这能在动用 WebRTC 之前救回大量「同网却连不上」的情况。
> - 原生客户端大文件**断点续传**——从中断处继续，而不是从 0% 重来。
> - 一条**兜底链路**，从最便宜的路径开始：局域网 HTTP 直推 → HTTP 反向拉取 → WebRTC P2P → S3 兼容中继。只有更便宜的一档连不上时才进入下一档。
> - **Web 客户端**，让访客/公司机器无需安装即可接收。
>
> 协议说明（英文）：https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md
>
> **技术栈。** 后端 Spring Boot（Java 17）+ MySQL，实时用 Centrifugo（WebSocket，向你所有已登录设备推送更新），Web 客户端用 Next.js，Flutter 覆盖 iOS/Android/macOS/Windows/Linux，另有 HarmonyOS 客户端。整套可自托管——README 里有 5 分钟 Docker 路径。
>
> **许可。** AGPL-3.0-or-later。自用或组织内自托管在 AGPL 下免费且不受限。仅当 AGPL 无法覆盖时才需要单独的商业许可（例如发布闭源改造后的网络服务）。我不打算搞 open-core 的「钓鱼换饵」——你自托管的代码就是跑官方服务的同一份代码。
>
> **隐私。** 文本经服务端同步时，消息正文会在服务端静态加密；元数据（类型、时间戳、会话 id）保持可读以便同步工作，且服务端不对消息正文做搜索。文件通过 S3 预签名 URL 传输。如果你自托管，这一切都在你自己的基础设施上。
>
> **诚实的局限：**
>
> - 完整体验需要原生客户端；Web 客户端受浏览器能力所限，是有意为之的取舍。
> - 部分增强路径（反向拉取、跨网）需要登录，因为服务端要协调探测。纯同网局域网原生传输可以不登录。
> - 有官方托管版（国际 shrimpsend.com；以及独立的国内版），但你不需要用它——自托管就完全不碰我们的服务器。
> - 这是个年轻项目，有粗糙的地方，我真心想知道它在你那儿哪里会出问题。
>
> **最需要你帮的：** 试一试自托管路径，告诉我文档哪里坑了你；开 issue；告诉我反向拉取对你的场景是否和对我一样有用。代码里标了一些 `good first issue` 可以上手。
>
> 接下来几个小时我都在，会回答问题。之后我会继续在 GitHub Discussions（https://github.com/shrimpsend/shrimpsend/discussions）回复，这样我下线时也不会漏掉。感谢围观。
