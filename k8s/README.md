# k8s — GitOps on k3s

Declarative cluster state, delivered by Argo CD. This file explains the layout and
*why* it is shaped this way; per-directory READMEs cover setup details.

## Layout

```
k8s/
├── infrastructure/   cert-manager + Argo CD — bootstrap, applied by hand once
├── argocd-apps/      app-of-apps: the root Application + one Application per workload
├── apps/             workloads, each as base/ + overlays/{prod,test}
└── monitoring/       Prometheus, Grafana, Loki — Argo CD multi-source (Helm + values)
```

## Why it's shaped this way

- **Bootstrap is separate from GitOps.** Argo CD cannot manage itself before it exists,
  so cert-manager and Argo CD are installed by hand (`kubectl apply -k`, pinned Helm
  charts) under `infrastructure/`. From then on everything else arrives through git.
- **app-of-apps.** One root `Application` watches `argocd-apps/`, giving exactly one owner
  per resource with self-heal and prune. Adding a workload means adding an `Application`
  there — nothing is applied by hand again.
- **base/overlays per app.** Each app keeps a single source of truth in `base/`; overlays
  set the namespace and hostname. The `test` overlay is validated on a disposable `k3d`
  cluster before prod, and `overlays/prod` is the path
  Argo CD syncs from `main`. This is why there is one copy of each manifest, not two repos.
- **Monitoring is multi-source, not overlays.** It composes an upstream Helm chart (pinned,
  from its own repo) with `$values` and extra manifests from this repo, so the upstream
  charts stay pristine and version bumps are a one-line change.

## TLS

cert-manager issues a `*.k8s.thelabdesk.com` wildcard via Let's Encrypt DNS-01. Secrets
don't cross namespaces, so each namespace declares its own `Certificate` into a local
`wildcard-k8s-tls` Secret.
