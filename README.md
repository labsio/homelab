# homelab

Self-hosted infrastructure for personal use, running on a Proxmox host.

A place to host my own services and to sharpen my skills by trying
out new tools and patterns — Kubernetes, GitOps, Infra-as-Code. The
end goal is a one-command bring-up of the entire stack on fresh
hardware.

## Where this is going

The main platform is **k3s** — declarative state, self-healing, GitOps
with Argo CD, TLS via cert-manager and Let's Encrypt DNS-01. Services
that are currently on Docker will move there over time.

**Docker Compose** stays as a simpler alternative for anyone who wants
to clone a minimal version of this homelab without standing up a
Kubernetes cluster.

## Structure

```
services/         Docker Compose services, one folder each
├── caddy/        reverse proxy, TLS termination
└── <service>/    self-contained — README, compose file, .env.example

k8s/              Kubernetes manifests
├── infrastructure/  cert-manager, argocd (bootstrap layer)
├── apps/            applications managed by Argo CD
├── monitoring/      Prometheus, Grafana, Loki, AlertManager
└── argocd-apps/     Argo CD Application resources (app-of-apps)
```

Each subdirectory has its own README with setup instructions.

## Services

| Service         | Subdomain                | Platform       | Purpose                     |
| --------------- | ------------------------ | -------------- | --------------------------- |
| caddy           | —                        | Docker         | Reverse proxy + TLS         |
| freshrss        | `rss.${DOMAIN}`          | Docker         | RSS aggregator              |
| rss-bridge      | — (internal)             | Docker         | Feed generator for freshrss |
| changedetection | `watch.${DOMAIN}`        | Docker         | Website change monitoring   |
| proxmox         | `proxmox.${DOMAIN}`      | Docker (proxy) | Hypervisor UI               |
| grafana         | `grafana.k8s.${DOMAIN}`  | k3s            | Monitoring dashboards       |

## Monitoring

A full observability stack runs on k3s — Prometheus for metrics, Loki
for logs, Grafana for dashboards, and AlertManager routing alerts to
Telegram. Deployed via Argo CD multi-source Applications. See
[k8s/monitoring](k8s/monitoring/kube-prometheus-stack/README.md) for
architecture, screenshots, and notes.

## Prerequisites

A full walkthrough will live on my blog, together with Ansible playbooks
and helper scripts to make setup as quick as possible. None of that
exists yet — it's part of the roadmap below.

For now, the basics:

- A Proxmox host (or any Linux host for Docker; a VM for k3s)
- A domain with DNS managed by Cloudflare
- Docker + Docker Compose for the Docker stack
- k3s for the Kubernetes stack

## What's next

- SOPS + age for secret management — see [docs/secrets.md](docs/secrets.md)
- Terraform for Cloudflare DNS (managed alongside the manifests)
- Ansible playbooks for host bootstrap — single command to install
  k3s and base configuration on a fresh Proxmox VM
- Migrate freshrss and changedetection from Docker to k3s
- Harden the Docker stack as a clean reference for simpler self-hosting

## License

MIT — see [LICENSE](LICENSE).
