# Warm-up comment bank (HN organic participation)

Use in the 2-3 weeks before launch. The goal is to build a small, genuine track record on HN so your account is not brand-new on launch day, and to learn how this audience talks about transfer/NAT/self-hosting topics.

## Rules (do not skip)

- Add real value first. Answer the question or share a concrete insight; mention ShrimpSend only when it is genuinely relevant, and disclose that you built it.
- Never astroturf: no sock-puppet accounts, no asking friends to upvote, no dropping links with no substance. HN detects and punishes this, and it is unrecoverable.
- 2-3 substantive comments per week is plenty. Quality over volume.
- If a thread is not actually about your problem space, do not shoehorn the product in.

## Where to look

Search HN (via Algolia: https://hn.algolia.com) and comment on live threads about:

- LocalSend, Syncthing, Snapdrop/Pairdrop, Magic Wormhole, KDE Connect
- NAT traversal, hole punching, WebRTC data channels, STUN/TURN
- Self-hosting file transfer / "send a file between my own devices"
- Windows firewall / one-way connectivity frustrations

## Disclosure line (reuse)

> Disclosure: I work on ShrimpSend, an open-source tool in this space, so I'm biased.

## Example comments (adapt, never paste verbatim)

### On a NAT/connectivity thread
> One thing that surprised me building a device-to-device transfer tool: reachability is directional. On the same Wi-Fi, a phone can usually POST to a desktop, but the desktop often can't connect back (Windows firewall, mobile listener restrictions, or the AP isolating clients). Retrying the same direction just times out. Flipping it — let the reachable side pull instead of insisting the sender push — recovers a surprising fraction of "same network but won't connect" cases before you even reach for WebRTC. (Disclosure: I work on a tool that does this.)

### On a LocalSend / LAN-transfer thread
> LocalSend is great when every device is on a reachable LAN with the app installed. The cases it doesn't target are cross-network sends, one-way firewalls, resume after a drop, and joining from a browser on a machine where you can't install anything. Those are exactly the gaps that pushed me to build something with a server-coordinated fallback chain. Different tradeoff — more moving parts, but it keeps working off the happy path. (Disclosure: biased, I build one of these.)

### On a self-hosting thread
> If you self-host this kind of thing, the detail that bit me was Centrifugo/WebSocket auth config — easy to get a backend up and then spend an hour on why the realtime channel won't connect. Worth documenting the required env vars with a startup validation check. Happy to share what we ended up with.

## Track it

Keep a short log so you do not over-post or repeat yourself:

```
Date | Thread (url) | Topic | Linked product? (Y/N) | Notes
```
