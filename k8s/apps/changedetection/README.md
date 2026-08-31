# changedetection

Watches web pages and notifies on changes — https://github.com/dgtlmoon/changedetection.io.
Migrated from the Docker Compose stack; runs the same two-container shape (the app plus a
headless-Chrome companion for JS-rendered pages) as an Argo CD-managed k3s workload.

## Architecture

```
Ingress (watch.k8s.thelabdesk.com) ──► changedetection:5000 ──► /datastore (PVC)
                                              │
                                              └──► playwright-chrome:3000 (NetworkPolicy-isolated)
```

## Why a NetworkPolicy, not just a private Docker network

`playwright-chrome` (dgtlmoon/sockpuppetbrowser) runs real Chrome instances rendering
arbitrary sites, with no authentication on its control port — reachable, it's a foothold
into the cluster network. The Docker Compose version kept it off `proxy_net` entirely; here
a default-deny-ingress `NetworkPolicy` plus one narrow allow (only the `changedetection` pod,
only port 3000) does the same job. Verified, not assumed: a pod in another namespace cannot
reach it, and `changedetection` can.

## Why `changedetection` runs as root but `playwright-chrome` doesn't

Checked empirically before writing the manifest (`kubectl exec ... -- id`), not guessed:

- `changedetection.io`'s image runs as root by default with no documented non-root mode,
  and writes `/datastore` as root — the same class of constraint that gave linkding its
  `uid: 33` requirement, except no working non-root UID is documented here. Forcing
  `runAsNonRoot` would break the write path, so the container keeps root but still drops
  all capabilities, disables privilege escalation, and runs under the `RuntimeDefault`
  seccomp profile.
- `sockpuppetbrowser` already runs as `uid 1000` (`chrome`) out of the box, so its
  `securityContext` declares `runAsNonRoot: true` / `runAsUser: 1000` explicitly — a real
  constraint the image already satisfies, not a hopeful one.

Because of the root container, the namespace's Pod Security Standard is `baseline`, not
`restricted` (which requires every pod to declare non-root).

## `/dev/shm` for Chrome

Chrome's default shared-memory allocation is too small in a container and crashes under
rendering load. An in-memory `emptyDir` (`medium: Memory`, capped at 1Gi) is mounted at
`/dev/shm` for exactly this reason — the same fix the Docker Compose version got for free
from Docker's larger default `/dev/shm`.

## Layout

`base/` holds the namespace-agnostic manifests; each overlay sets the namespace and its own
hostname — same pattern the rest of `k8s/apps/` uses:

- `overlays/prod/` — `watch.k8s.thelabdesk.com`, namespace `changedetection`. Argo CD syncs
  this path from `main`.
- `overlays/test/` — `watch-test.k8s.thelabdesk.com`, namespace `changedetection-test`. For
  validation on a throwaway `k3d` cluster or a test namespace on the real cluster.

## Validate / apply

```bash
kubectl kustomize k8s/apps/changedetection/overlays/prod   # render, no cluster needed
kubectl apply -k k8s/apps/changedetection/overlays/test    # e.g. on a k3d cluster
```

## Storage

2Gi `PersistentVolumeClaim` on `local-path` (k3s default storage class) — holds watch
definitions, diff history, and notification settings.

## Backup

The `changedetection-data` PVC is the only state worth backing up; `playwright-chrome`
holds nothing persistent and can be recreated from its image at any time.
