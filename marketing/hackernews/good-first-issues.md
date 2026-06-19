# Good first issues — backlog for launch

Eight contributor-friendly issues to file before the Show HN launch. A visible `good first issue` list converts HN traffic into contributors, not just stargazers.

How to file (run from the repo, requires `gh auth login`):

```bash
gh label create "good first issue" --color 7057ff --description "Good for newcomers" --force
gh issue create --title "<title>" --label "good first issue,<area>" --body "<body>"
```

Keep each issue small (under ~2 hours for a newcomer), with clear acceptance criteria and pointers to the relevant files. Do not assign them; let contributors claim them in a comment.

---

## 1. Docs: add a docker-compose troubleshooting section
- Labels: `good first issue`, `documentation`, `self-hosting`
- Why: the 5-minute path in the README is the first thing HN visitors try; common failures (port already in use, MySQL healthcheck timeout, missing `config.docker.json`) deserve a short FAQ.
- Acceptance: a "Troubleshooting" subsection under the Docker instructions in [docs/SELF_HOST.md](../../docs/SELF_HOST.md) covering at least port conflicts, MySQL not ready, and where logs live.

## 2. Docs: English walkthrough screenshots for first-run
- Labels: `good first issue`, `documentation`
- Why: README screenshots show the UI but not the first-run flow (sign up on your own instance, add a second device).
- Acceptance: 3-4 annotated screenshots or a short numbered list under "Try it in 5 minutes" in [README.md](../../README.md).

## 3. Web: copy-to-clipboard button on received text messages
- Labels: `good first issue`, `web`, `enhancement`
- Why: text/clipboard sending is a core use case; a one-click copy on the web client is a small, self-contained UI addition.
- Acceptance: a copy button on text messages in the web chat view with a "copied" toast; lint passes (`npm run lint` in `web/`).

## 4. Web: show the active transfer path in the UI
- Labels: `good first issue`, `web`, `enhancement`
- Why: the connection diagnostic already knows whether a transfer used LAN / reverse pull / WebRTC / S3; surfacing it as a small badge reinforces the product's differentiator.
- Acceptance: a label/badge near the transfer indicating the path used.

## 5. Backend: validate and document required environment variables on startup
- Labels: `good first issue`, `backend`, `self-hosting`
- Why: self-hosters hit confusing failures when an env var is missing; a clear startup check improves the first-run experience.
- Acceptance: backend logs a clear, actionable message naming any missing required variable (e.g. datasource URL, Centrifugo keys) instead of failing deep in the stack.

## 6. i18n: audit the English strings in the web client
- Labels: `good first issue`, `web`, `i18n`
- Why: the project is bilingual (zh/en); the English landing/app strings benefit from a native-speaker pass before HN traffic.
- Acceptance: a PR fixing awkward or inconsistent English strings in `web/`, with before/after noted in the description.

## 7. Repo: add a CONTRIBUTING quickstart for web-only contributors
- Labels: `good first issue`, `documentation`
- Why: many contributors only want to touch the web client and do not need the full backend/Flutter setup.
- Acceptance: a short "Web-only setup" note in [CONTRIBUTING.md](../../CONTRIBUTING.md) pointing the web client at the official/your dev API.

## 8. Protocol: add request/response examples to the English summary
- Labels: `good first issue`, `documentation`
- Why: [shared/protocol.en.md](../../shared/protocol.en.md) describes endpoints; concrete curl examples for `/probe`, `/transfer-status`, and a presigned upload make it easy to verify a self-hosted instance.
- Acceptance: a short "Examples" section with copy-pasteable curl commands.
