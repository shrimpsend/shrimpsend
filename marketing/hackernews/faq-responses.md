# FAQ response templates

Pre-written answers to the questions HN reliably asks. Keep them as raw material: adapt to the exact wording of each comment, never paste the same canned text twice in one thread. Tone: factual, no hype, never disparage competitors. If you're offline, a teammate can use these to keep the thread alive.

---

## "How is this different from LocalSend?"

LocalSend is excellent when every device is on a reachable LAN with the app installed. ShrimpSend targets the cases it doesn't: asymmetric/one-way connectivity (phone can reach PC but not vice versa), cross-network sends, resume after a disconnect, and joining from a browser on a machine where you can't install anything. The tradeoff is more moving parts (there's a coordinating server for the fallback chain), in exchange for working off the happy path. If your devices are always on a clean LAN, LocalSend may be all you need.

## "How is this different from Syncthing?"

Different model. Syncthing continuously syncs folders across devices; it's great for keeping directories identical. ShrimpSend is for explicit, one-shot-ish sends into a device conversation — "send this screenshot to my laptop now" rather than "keep these folders in sync forever." Many people use both.

## "Why not Magic Wormhole / Pairdrop / Snapdrop?"

Those are great for one-off transfers. ShrimpSend optimizes for repeated sends between *your* devices that persist in a conversation, plus resume and the cross-network fallback chain. If you just need to beam one file to someone once, wormhole is hard to beat.

## "AGPL — what's the catch? Is this open-core?"

No open-core split: the code you self-host is the same code that runs the hosted service. AGPL-3.0 means self-hosting for yourself or your organization is free; if you modify it and offer it as a network service to third parties, AGPL asks you to share your modifications. There's a separate commercial license only for orgs that can't comply with that (e.g. closed-source modified SaaS, OEM/white-label). Details: https://github.com/shrimpsend/shrimpsend/blob/main/LICENSE-Commercial.md

## "Why should I trust you with my files?"

You don't have to — self-host and your files never touch our servers. The code is open and auditable. On the hosted service, files move via presigned S3 URLs and text bodies are encrypted at rest. For maximum control, point it at your own S3-compatible storage or run the whole stack yourself.

## "It's from China — data sovereignty / privacy?"

The codebase is fully open and the international hosted edition (shrimpsend.com) runs on its own cluster, separate from the China edition (xiachuan.net). If sovereignty matters to you, self-host: the stack runs entirely on your own infrastructure and the source is the same as what we run.

## "What about encryption / E2E?"

Today, text bodies are encrypted at rest on the server and transport is TLS; same-LAN direct transfers don't traverse our servers at all. Full end-to-end encryption for relayed transfers isn't there yet — happy to discuss the design in an issue if that's a blocker for you. I'd rather be precise about what exists than overclaim.

## "Does it cost money?"

Free for 3 devices. Beyond that there are paid tiers (subscription internationally, one-time purchase in China) mostly for more devices and hosted upload quota. But if you're here for the open-source stack, self-hosting removes the limits entirely.

## "Can I use my own S3 / storage?"

Yes — you can point it at any S3-compatible endpoint instead of the hosted bucket. S3 is the fallback relay path, not the primary one; LAN/WebRTC are preferred when reachable.

## "Show me the protocol / how reverse-pull works"

English summary: https://github.com/shrimpsend/shrimpsend/blob/main/shared/protocol.en.md — covers HTTP push, reverse pull (with `Range`-based resume), WebRTC DataChannels, and the S3 multipart path. The short version: reachability is directional, so when the receiver can't accept a connection, the reachable side pulls instead of the sender pushing.

## "Self-host didn't work for me"

Sorry about that — which step and what error? There's a 5-minute Docker path in the README and a guide at docs/SELF_HOST.md. If you can open an issue with the command, your OS, and which service failed (MySQL :3306 / Centrifugo :8000 / backend :9000 / web :3000), I'll fix the docs or the bug. (Use this to drive a real-time doc fix during the launch window.)

## "HarmonyOS? Why?"

It's a real platform for part of our user base. It's not central to the HN story — the interesting parts are the transfer protocol and self-hosting. Happy to go deeper on those instead.

## Tone reminders

- Concede valid criticism immediately and turn it into an issue.
- Never say "revolutionary," "best," or "simply." Describe behavior and tradeoffs.
- Thank critics as much as fans — sharp questions are the most useful thing a launch gets.
