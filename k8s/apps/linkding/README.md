# linkding

Self-hosted bookmark manager — https://github.com/sissbruecker/linkding

## Secret

The superuser password is read from a `linkding-credentials` Secret that is
**not** committed to git. Create it once, out-of-band, before applying:

```bash
kubectl create secret generic linkding-credentials \
  --namespace linkding \
  --from-literal=superuser-password='<a-strong-password>'
```

Migrating this to a SOPS-encrypted `linkding-credentials.enc.yaml` is on the
roadmap — see [../../../docs/secrets.md](../../../docs/secrets.md).

## Layout

`base/` holds the namespace-agnostic manifests; each overlay sets the namespace
and its own hostname:

- `overlays/prod/` — `linkding.k8s.thelabdesk.com`, namespace `linkding`. Argo CD
  syncs this path from `main`; you don't apply it by hand.
- `overlays/test/` — `linkding-test.k8s.thelabdesk.com`, namespace `linkding-test`.
  For validation on a throwaway k3d cluster or a test namespace.

## Validate / apply

```bash
kubectl kustomize k8s/apps/linkding/overlays/prod   # render, no cluster needed
kubectl apply -k k8s/apps/linkding/overlays/test    # e.g. on a k3d cluster
```

## Storage

1 Gi `PersistentVolumeClaim` on `local-path` (k3s default storage class).
