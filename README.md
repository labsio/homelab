# homelab

Self-hosted services for personal use, running on Proxmox.
Services are containerised with Docker Compose and published
through a single Caddy reverse proxy with automatic HTTPS.

Public repository — migrated iteratively from a private
development setup, one service per pull request.

## Structure

services/
├── caddy/ reverse proxy, TLS termination (ACME DNS-01 via Cloudflare)
└── <service>/ one folder per service, each with its own README

Each service folder is a self-contained Docker Compose project
with its own `README.md`, `docker-compose.yml`, and `.env.example`.
They share an external Docker network `proxy_net` so Caddy can
reach them.

## Services

| Service         | Subdomain           | Purpose                   | Status   |
| --------------- | ------------------- | ------------------------- | -------- |
| caddy           | —                   | Reverse proxy + TLS       | migrated |
| freshrss        | `rss.${DOMAIN}`     | RSS aggregator            | planned  |
| changedetection | `watch.${DOMAIN}`   | Website change monitoring | planned  |
| proxmox         | `proxmox.${DOMAIN}` | Hypervisor UI (proxied)   | migrated |

## Prerequisites

- Docker + Docker Compose on the host
- External Docker network: `docker network create proxy_net`
- A domain with DNS managed by Cloudflare (for ACME DNS-01)
- DNS records for each service subdomain pointing at the host

## Bringing up a service

Each service is independent:

```bash
cd services/<name>
cp .env.example .env
# edit .env with real values
docker compose up -d
```

Start `caddy` first — it is the reverse proxy for everything else.

## Roadmap

- [ ] Ansible playbooks for host bootstrap (Docker, network, firewall)
- [ ] GitHub Actions for Compose / Caddyfile validation on PR
- [ ] Centralised backups of named volumes
- [ ] Monitoring stack (Prometheus + Grafana)

## License

MIT — see [LICENSE](LICENSE).
