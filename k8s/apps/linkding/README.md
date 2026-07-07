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

Migrating this to External Secrets Operator + Azure Key Vault is on the roadmap.

## Apply

```bash
kubectl apply -k .
```

## Storage

1 Gi `PersistentVolumeClaim` on `local-path` (k3s default storage class).
