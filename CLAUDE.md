# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
pre-commit run --all-files              # trailing-ws, eof, check-yaml, gitleaks, hadolint, yamllint
yamllint -d relaxed .                   # exactly what CI runs on PRs
kubectl kustomize k8s/apps/linkding     # render/validate a kustomization without a cluster

# Validate a Compose service the way CI does (from services/<svc>/)
cp .env.example .env && docker compose config --quiet
```

There is no build or test suite — validation is lint + render + `compose config`.

## Two delivery paths

`k8s/` (k3s + Argo CD) is the main platform; `services/` (Docker Compose + Caddy) is the
simpler alternative kept working for anyone who wants the homelab without Kubernetes.
The same service may exist on only one of the two — the README service table is the
source of truth for which platform hosts what.

## k8s/ — GitOps layering

Bootstrap is deliberately split from GitOps:

1. **`k8s/infrastructure/`** — applied by hand, once, before Argo CD can manage anything.
   cert-manager and Argo CD themselves are installed with `helm install` (commands live in
   each subdirectory's README, with pinned chart versions); the manifests here are only the
   extras (`ClusterIssuer`, `Certificate`, `Ingress`) applied via `kubectl apply -k .`.
2. **`k8s/argocd-apps/root.yaml`** — the app-of-apps root `Application` (automated sync,
   prune, self-heal) pointed at `k8s/argocd-apps/`. Applied once by hand; from then on
   everything else arrives through git.
3. **`k8s/apps/`, `k8s/monitoring/`** — the workloads the root app manages.

**Adding an app** therefore takes three edits: manifests in `k8s/apps/<name>/` with a
`kustomization.yaml`, an `Application` in `k8s/argocd-apps/<name>.yaml`, and the new file
added to `k8s/argocd-apps/kustomization.yaml` — the root app only sees what that
kustomization lists.

### Upstream Helm charts: multi-source Applications

Monitoring uses Argo CD **multi-source** `Application`s so upstream charts stay pristine:
source 1 is the chart from its own repo at a pinned `targetRevision`, its `valueFiles`
referencing `$values/k8s/monitoring/<chart>/values.yaml`; source 2 is this git repo with
`ref: values`, doubling as a Kustomize source for the extras (`Certificate`, `Ingress`,
`PrometheusRule`). Chart values and chart version live in git — never `helm upgrade --set`
by hand.

### Sync policies are intentionally not uniform

`root` and `linkding` are `automated` with `prune` + `selfHeal`. The monitoring
Applications deliberately have **no** `automated` block (manual sync only) and use
`ServerSideApply=true` for the large CRD-heavy charts. Don't "normalize" these.

### Patterns every k8s manifest follows

- **TLS:** one `Certificate` named `wildcard-k8s` per namespace, all issuing the same
  `*.k8s.thelabdesk.com` wildcard into a local `wildcard-k8s-tls` Secret. The repetition is
  required — Secrets don't cross namespaces — so a new namespace needs its own copy.
- `ingressClassName: traefik` (k3s built-in ingress), `storageClassName: local-path`
  (k3s built-in storage).
- The real domain `thelabdesk.com` and the maintainer's ACME email are hardcoded on
  purpose; earlier commits replaced placeholders with them. Don't reintroduce
  `example.com`.
- Deployments carry explicit resource requests/limits, probes, and a hardening
  `securityContext` (`allowPrivilegeEscalation: false`, drop ALL caps, `RuntimeDefault`
  seccomp). Match this in new workloads.

### k3s-specific settings that look wrong but aren't

Documented in `k8s/monitoring/kube-prometheus-stack/README.md`; don't revert them:

- `kubeControllerManager` / `kubeScheduler` / `kubeProxy` / `kubeEtcd` scrape targets are
  disabled — k3s bundles the control plane into one process, so enabling them yields
  permanent false "down" alerts.
- `grafana.initChownData.enabled: false` — the init chown fails on k3s + local-path.
- `ignoreDifferences` on `/status/terminatingReplicas` — newer Kubernetes added the field,
  older Argo CD schemas break diffing on it.
- Loki's datasource is declared in the kube-prometheus-stack values with
  `isDefault: false`, and the deprecated `loki-stack` chart's own datasource
  provisioning is switched off, so Prometheus stays the default datasource.

## services/ — Docker Compose path

Each service is a self-contained folder: `README.md`, `docker-compose.yml`,
`.env.example`. Conventions shared by all of them:

- Caddy is the single TLS terminator. It is **built locally** (`Dockerfile` +
  `xcaddy`) because the Cloudflare DNS plugin isn't in the official image; TLS uses
  DNS-01 so no inbound port 80 is needed.
- Networking: an **external** `proxy_net` (`docker network create proxy_net`, created
  once, out of band) joins a service to Caddy; anything a service talks to privately gets
  its own bridge network (`rss_net`, `changedetection_net`) and is *not* on `proxy_net`.
- Every service sets `restart: unless-stopped`, `deploy.resources.limits`, and
  json-file log rotation (`max-size: 10m`, `max-file: 3`).
- Hostnames come from `${DOMAIN}` in the Caddyfile, not hardcoded — the opposite of the
  k8s side.
- Adding a service means also adding it to the `matrix.service` list in
  `.github/workflows/compose-validate.yml`, or CI silently never validates it.

## Repo conventions

- **Pin every image and chart.** No `:latest`. Look up the real current tag rather than
  inventing one — some images don't use semver (`rssbridge/rss-bridge:sha-68539df`).
- **Secrets are never committed.** They are created out-of-band with `kubectl create
  secret` and referenced by name: `cloudflare-api-token` (cert-manager),
  `linkding-credentials`, `grafana-admin`, `telegram-bot-token` (monitoring). The exact
  commands live in the relevant README. `gitleaks` runs pre-commit. Encrypting Secrets in
  git with SOPS + age is roadmap, not done.
- This is a **public** repo: English only, no Cyrillic, no personal data beyond what is
  already there.
- Every meaningful subdirectory has its own README with setup instructions — update it
  when the manifests change.
- Commits are one-line conventional-commit subjects (`type(scope): summary`), no body
  unless needed; work lands via PR. Never add Claude attribution to commits or PRs.
- `check-added-large-files` caps files at 500 KB — matters for the Grafana/Telegram
  screenshots under `k8s/monitoring/kube-prometheus-stack/screenshots/`.

## Cluster changes go through git

The cluster is changed only by GitOps: PR → merge → Argo CD syncs; roll back with
`git revert`. Never `kubectl edit` a managed resource and never configure through an
app's UI (a datasource added in the Grafana UI broke pod startup on restart) — self-heal
will fight you, or the change will vanish.
