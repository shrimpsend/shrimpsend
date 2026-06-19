# ShrimpSend v1.4.9 — release notes (draft)

Draft for the GitHub Release that anchors the Show HN launch. Fill the changelog bullets from `git log` before publishing, then create the release with a tag that matches the client version.

> Publish with (after reviewing the bullets):
>
> ```bash
> git tag -a v1.4.9 -m "ShrimpSend v1.4.9"
> git push origin v1.4.9
> gh release create v1.4.9 --title "ShrimpSend v1.4.9" --notes-file docs/RELEASE_NOTES_v1.4.9.md
> ```

## Highlights

ShrimpSend is an AGPL-3.0 file and message transfer tool for your own devices. It is LAN-first, recovers across NAT and one-way firewalls via reverse pull, resumes large transfers after disconnects, and lets a browser temporarily join a device conversation. The full stack is self-hostable: Spring Boot + Centrifugo + MySQL + S3-compatible storage.

This is the build referenced in the launch (`app/pubspec.yaml` version `1.4.9+49`).

## What's in this release

<!-- Replace these placeholders with real entries from: git log --oneline <previous-tag>..HEAD -->

- Added: ...
- Improved: ...
- Fixed: ...

## Platforms

iOS, Android, macOS, Windows, Linux, Web, HarmonyOS.

## Self-hosting

Run the full stack on your own infrastructure under AGPL-3.0-or-later. See [docs/SELF_HOST.md](SELF_HOST.md) and the 5-minute Docker path in the [README](../README.md#try-it-in-5-minutes).

## Transfer protocol

LAN direct push, reverse pull, WebRTC P2P, and S3-compatible relay. English summary: [shared/protocol.en.md](../shared/protocol.en.md).

## Links

- Source: https://github.com/shrimpsend/shrimpsend
- International hosted service: https://shrimpsend.com
- License: AGPL-3.0-or-later ([LICENSE](../LICENSE)) · Enterprise: [LICENSE-Commercial.md](../LICENSE-Commercial.md)
