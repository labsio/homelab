# linkding

Self-hosted bookmark manager — https://github.com/sissbruecker/linkding

## Apply

```bash
kubectl apply -k .
```

## Storage

1 Gi `PersistentVolumeClaim` on `local-path` (k3s default storage class).

## TODO

- Pin image to a specific version instead of `:latest`
- Move `LD_SUPERUSER_PASSWORD` to a `Secret` (sealed-secrets or external-secrets)
