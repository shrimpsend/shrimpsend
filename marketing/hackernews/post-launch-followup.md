# Post-launch follow-up (D+0 to D+7 and beyond)

A single HN spike does not equal sustained growth. Star retention comes from a steady release cadence and fast issue response. The first week converts launch attention into a real project.

## Day-by-day

| Day | Action |
|---|---|
| D+0 | Monitor HN + GitHub notifications. Fix self-host doc breakage live. Respond to every substantive comment. |
| D+1 | If HN went well (>100 points), publish/refresh the GitHub Release notes to echo the features people asked about. Reply to overnight comments. |
| D+2-3 | Turn the top HN questions into a tracked `docs/FAQ.md` or pinned GitHub Discussion. Triage and label every issue opened during the launch. |
| D+4-7 | Respond to all new issues within 72 hours. Merge or comment on early PRs quickly — first-time contributors who get a fast response come back. |
| D+7 | Review metrics (below) and decide whether to run a second-round technical post. |

## Issue & PR SLA (the part that retains stars)

- New issue: first response within 72 hours, even if it's just triage.
- `good first issue` PRs: review within a few days; a stale newcomer PR is a lost contributor.
- Keep labels tidy (`bug`, `enhancement`, `self-hosting`, `good first issue`) so the repo reads as actively maintained.

## Second-round content (space at least 2 weeks after launch)

Do not re-submit a Show HN. Instead, submit a regular HN post or share elsewhere:

- "How we implement reverse-pull file transfer" — the deep version of [blog-reverse-pull.md](blog-reverse-pull.md).
- "Self-hosting ShrimpSend in 10 minutes" — a polished walkthrough born from the dry-run fixes.

## Metrics to evaluate (D+7)

| Tier | HN result | GitHub 7-day delta | Read as |
|---|---|---|---|
| Over-target | Top 5, 300+ points | 500+ stars | Product + narrative + luck aligned |
| On-target | Front page 4-8h, 80-150 points | 150-300 stars | Healthy result for an indie tool |
| Acceptable | 30-80 points | 50-150 stars | Still real SEO + community value |
| Needs review | <30 points | <50 stars | Re-examine title, first comment, README try-it friction |

Also track quality signals, not just stars: number of self-host attempts that succeeded, issues opened by non-team accounts, and any PRs from first-time contributors. Those predict whether the project keeps growing after the spike fades.

## Retro (write it down)

After D+7, capture: which title/first-comment framing landed, which objection came up most, where self-host still tripped people, and the single biggest fix for next time. Feed it back into the README and these docs.
