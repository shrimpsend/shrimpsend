# Self-host dry run — pre-launch checklist

Goal: before the Show HN, have 3-5 developers run a self-hosted instance from a clean machine using only the public docs, and fix every doc gap they hit. On launch day, "I tried to self-host and it didn't work" is the most damaging comment; this is the cheapest way to prevent it.

## Recruit

- 3-5 people who have not set up the project before (the unfamiliarity is the point).
- Mix of OS: at least one macOS (arm64), one Linux x86_64, ideally one Windows (WSL).
- They should use only the public README + [docs/SELF_HOST.md](../../docs/SELF_HOST.md) — no asking the maintainer in chat. Every question they need to ask is a doc bug.

## Path under test

The path HN visitors will follow first:

```bash
git clone https://github.com/shrimpsend/shrimpsend.git
cd shrimpsend
./scripts/setup-local-config.sh
docker compose up -d
cd web && npm ci && npm run dev
# open http://localhost:3000, sign up, add a second device/browser, send a message
```

## Tester card (each tester fills one)

```
Tester:            ______________________
OS / arch:         ______________________
Date:              ______________________
Clone -> running:  ____ minutes
Got stuck? Where:  ______________________
Exact error(s):    ______________________
Doc gap found:     ______________________
First message sent successfully? (Y/N)
LAN transfer worked between two devices? (Y/N / not tested)
Notes:             ______________________
```

## What to verify

- [ ] `git clone` + `setup-local-config.sh` produces a working `.env` and `config.docker.json` with no manual edits (or the required edits are documented).
- [ ] `docker compose up -d` brings MySQL, Centrifugo, and backend healthy.
- [ ] Web client starts and reaches the backend on :9000.
- [ ] Account creation works on the self-hosted instance.
- [ ] A second device/browser can join and receive a text message.
- [ ] (If two physical devices available) LAN direct transfer works.
- [ ] Total clean-machine time to first message is under ~10 minutes.

## Common failure points to watch

- Ports already in use (3306 / 8000 / 9000 / 3000).
- MySQL healthcheck timing out on first boot (slow disk / arm64 image pull).
- Centrifugo image tag mismatch (`docker-compose.yml` pins `centrifugo:v5`; README/docs reference v6 — confirm which the compose path actually needs and align).
- Missing or placeholder Centrifugo keys causing the backend to reject the WebSocket connection.
- `npm ci` failing on Node < 20.

## Output

For every gap a tester hits, either fix the doc/script in the same week or file a tracked issue. Re-run the dry run until a fresh tester reaches "first message sent" with zero out-of-band questions. Only then check the "3 testers succeeded" box in the launch-day playbook.
