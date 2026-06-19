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
