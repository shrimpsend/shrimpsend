# Hacker News cold-start kit

Execution assets for the ShrimpSend Show HN launch. Goal: **GitHub attention** (stars, issues, forks, self-host attempts). Constraint: the maker can do English interaction for only ~2-3 hours on launch day, so the strategy leans on a long maker comment + pre-written FAQ + GitHub Discussions to keep answering after going offline.

HN audience reads English and uses the international site ([shrimpsend.com](https://shrimpsend.com)); don't bring up the China edition unless asked.

## One-line positioning

> AGPL open-source cross-device file transfer: LAN-first, automatic reverse-pull across NAT / one-way firewalls, resume for large files, and a browser can temporarily join a device conversation.

In HN minds: not "another cloud drive" — the cross-network upgrade to LocalSend, plus a self-hostable private device conversation.

## Files

| File | Use |
|---|---|
| [launch-day-playbook.md](launch-day-playbook.md) | Timing, titles, link target, minute-by-minute, reply priority, T-24h checklist |
| [maker-comment.md](maker-comment.md) | The first comment to paste ~60s after posting |
| [faq-responses.md](faq-responses.md) | Templates for the questions HN always asks |
| [good-first-issues.md](good-first-issues.md) | 8 ready-to-file contributor issues |
| [self-host-dry-run.md](self-host-dry-run.md) | Pre-launch test protocol so self-host doesn't break on the day |
| [warmup-comment-bank.md](warmup-comment-bank.md) | Organic HN participation in the 2-3 weeks before |
| [blog-reverse-pull.md](blog-reverse-pull.md) | Technical warm-up post on the differentiator |
| [post-launch-followup.md](post-launch-followup.md) | D+0 to D+7, second-round content, metrics |

## Repo changes that ship with this kit

- [README](../../README.md#try-it-in-5-minutes): 5-minute Docker quickstart + English protocol link.
- [shared/protocol.en.md](../../shared/protocol.en.md): English protocol summary (technical credibility anchor).
- [docs/RELEASE_NOTES_v1.4.9.md](../../docs/RELEASE_NOTES_v1.4.9.md): release notes draft.
- `.github/`: issue templates (bug / feature / self-host) + PR template.

## Timeline

1. **Weeks 1-2** — GitHub "star-ready" polish: README/GIF, 5-min try, English protocol, good first issues, Release, templates.
2. **Weeks 2-3** — Warm-up: organic HN comments, the reverse-pull post, self-host dry run.
3. **Week 4** — Show HN on Tue/Wed 21:00 Beijing, 2-3 hours of high-frequency replies.
4. **D+0 to D+7** — Triage, FAQ, fast issue response, evaluate, plan round two.

## Hard rules

No bought upvotes, vote rings, or sock-puppets — HN detects it and the penalty is permanent. Lead with the technology, not pricing. Concede fair criticism and convert it into issues.
