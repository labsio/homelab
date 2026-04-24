# ChangeDetection — website change monitor

Watches web pages and notifies on changes. Handles JS-heavy sites via a
companion headless-Chrome service (Playwright). Reached through Caddy at
`watch.${DOMAIN}`, stores data in the `changedetection_data` volume.

## Architecture

```
Caddy (watch.${DOMAIN}) ──► changedetection:5000 ──► /datastore (changedetection_data volume)
                                    │
                                    └──► playwright-chrome:3000   (internal only)
```

- `changedetection` is on both `proxy_net` (for Caddy) and `changedetection_net` (for Playwright)
- `playwright-chrome` is on `changedetection_net` only — not reachable from outside

## Prerequisites

- External Docker network `proxy_net` (shared with Caddy)
- Site block in `services/caddy/Caddyfile` routing `watch.${DOMAIN}` → `changedetection:5000` (already present)
- DNS record `watch.${DOMAIN}` pointing at the Caddy host

## Setup

```bash
cp .env.example .env
# edit TZ and BASE_URL
docker compose up -d
```

Then open `https://watch.${DOMAIN}` and start adding watches.

## Why a separate `changedetection_net`

Playwright-chrome launches real Chrome instances and has no authentication
on its control port. Keeping it off `proxy_net` means only `changedetection`
can reach it — other services on the shared proxy network cannot call it,
and it cannot be exposed by accident.

## Why Playwright and not the Python requests fetcher

The default fetcher only sees the raw HTML the server sends. Many modern
sites render content in the browser via JavaScript, so the diff would be
"nothing changed" every time. Playwright runs a real Chrome, waits for
rendering, then hands the DOM to changedetection — producing diffs that
match what a human sees.

Trade-off: ~1 GB extra RAM for the browser container.

## Why a pinned image version

The image is pinned to `0.54.10` instead of `:latest`. changedetection
ships breaking changes between minor versions (schema migrations,
fetcher API changes). Pinning means `docker compose pull && up -d`
only updates what the Dockerfile says — no surprise breakage when
upstream rolls forward.

Update by bumping the tag in `docker-compose.yml`, not by following `:latest`.

## Backup

The only state worth backing up is the `changedetection_data` volume —
it contains watch definitions, diff history, and notification settings.

```bash
docker run --rm \
  -v changedetection_changedetection_data:/data \
  -v "$PWD":/backup \
  alpine tar czf /backup/changedetection-$(date +%F).tar.gz -C /data .
```

The `playwright-chrome` container holds no persistent state — it can be
recreated from the image at any time.

## Notes

- `BASE_URL` matters for notification links. If it is empty, links in
  emails/webhooks point at `http://changedetection:5000/...` (the
  internal hostname), which is useless outside the Docker network.
  Set it to the public URL (`https://watch.${DOMAIN}`).
- `MAX_CONCURRENT_CHROME_PROCESSES=5` bounds memory use. Each Chrome
  instance is ~150–250 MB; five in parallel fits in the 1 GB container
  limit with headroom.
- No healthcheck is defined. The upstream image does not ship one,
  and `wget`/`curl` are not present to add one cleanly. `restart:
unless-stopped` covers process crashes.
