# Caddy — reverse proxy

Reverse proxy with automatic TLS via Let's Encrypt DNS-01 challenge
(Cloudflare). Terminates HTTPS for all public-facing services.

## Architecture

External request → Caddy (port 443) → internal Docker network → service

## Prerequisites

- External Docker network `proxy_net` (created once: `docker network create proxy_net`)
- Cloudflare API token with `Zone.DNS:Edit` + `Zone.Zone:Read` on your zone
- DNS records for each subdomain pointing to this host

## Setup

```bash
cp .env.example .env
# edit .env with real values
docker compose up -d
```

## Adding a new service

1. Add a site block to `Caddyfile`
2. Ensure the target service is on `proxy_net` network
3. `docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile`

## Why DNS-01 instead of HTTP-01

DNS-01 does not require port 80 inbound access, making this work
for internal services and behind NAT. Trade-off: requires DNS API
access for the provider.
