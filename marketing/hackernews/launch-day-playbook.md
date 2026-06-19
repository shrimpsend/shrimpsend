# Show HN launch-day playbook

Everything needed to execute the post itself. Optimized for the constraint: you can only do English interaction for ~2-3 hours on launch day.

## When

| Beijing time | US Pacific | Why |
|---|---|---|
| Tue or Wed, 21:00-22:00 | ~6:00-7:00 AM PT | US morning HN peak; you stay interactive until ~24:00 Beijing |

Avoid Monday (crowded), Friday afternoon PT, and US holidays.

## Title (decide one before posting)

1. `Show HN: ShrimpSend – AGPL cross-device file transfer with LAN-first and reverse-pull fallback`
2. `Show HN: Open-source file transfer between your devices (resume, WebRTC, self-hostable)`
3. `Show HN: When HTTP push fails, pull instead – AGPL device-to-device transfer`

Rules: factual, `Show HN:` prefix, include at least one of `AGPL` / `self-hostable`. No hype words.

## Link target

- **Submission URL:** https://github.com/shrimpsend/shrimpsend (the goal is GitHub attention, so link the repo, not the landing page).
- In the first comment, add: https://shrimpsend.com (to try) and the protocol doc (depth).

## Minute-by-minute

| T+ | Action |
|---|---|
| T-24h | Run the final pre-launch checklist below. |
| T+0 | Submit the Show HN with the chosen title, URL = the repo. |
| T+1 min | Paste the maker comment from [maker-comment.md](maker-comment.md). |
| T+0 to T+3h | Refresh HN + GitHub notifications every few minutes. Reply by priority (below). |
| Last 10 min online | Post a short note: "Heading offline for a bit — I'll keep replying in GitHub Discussions." |
| After offline | Teammate (if any) monitors using [faq-responses.md](faq-responses.md); otherwise replies resume in Discussions. |

Do **not** ask anyone to upvote, and do not submit from a brand-new account — use the account warmed up via [warmup-comment-bank.md](warmup-comment-bank.md).

## Reply priority (your 2-3 hour window)

1. **Technical scrutiny** (protocol, security, AGPL) → detailed answer + link to the doc. These set the tone of the whole thread.
2. **"How does it compare to X?"** → use [faq-responses.md](faq-responses.md); never disparage the competitor.
3. **Self-host got stuck** → fix the doc/bug live and reply with the fix or an issue link. Highest-leverage for the GitHub goal.
4. **Feature requests** → "Good idea — filed as #NNN." Converts a comment into a tracked issue.
5. **Praise** → brief thanks, point to star / self-host.

## Pre-launch checklist (T-24h)

- [ ] README has the 5-minute Docker quickstart and (ideally) a short demo GIF near the top.
- [ ] A demo GIF/screenshot exists (record: pick device → drag file → connection diagnostic showing the path). If not ready, ship without it rather than with a broken image.
- [ ] GitHub Release published (see [../../docs/RELEASE_NOTES_v1.4.9.md](../../docs/RELEASE_NOTES_v1.4.9.md)).
- [ ] At least 5 `good first issue`s filed (see [good-first-issues.md](good-first-issues.md)).
- [ ] GitHub Discussions enabled.
- [ ] Issue/PR templates live (`.github/`).
- [ ] At least 3 testers reached "first message sent" on a clean machine (see [self-host-dry-run.md](self-host-dry-run.md)).
- [ ] shrimpsend.com signup/download flow works end to end.
- [ ] Maker comment + FAQ finalized in English.
- [ ] Calendar block set: post 21:00, comment 21:05, high-frequency replies until ~24:00 Beijing.
- [ ] (Optional) An English-fluent teammate lined up to cover ~2 hours after you go offline.

## What NOT to do

- No bought upvotes, vote rings, or sock-puppets. HN detects this and the penalty is permanent.
- Don't lead with pricing or App Store links — HN wants the tech; pricing goes in the FAQ if asked.
- Don't argue defensively. Concede fair points and convert them into issues.
