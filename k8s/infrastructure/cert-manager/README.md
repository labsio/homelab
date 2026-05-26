# cert-manager

Issues TLS certificates from Let's Encrypt via DNS-01 challenge using Cloudflare.

## Install

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set crds.enabled=true
```

## Cloudflare API token

Create a token with `Zone.DNS:Edit` and `Zone.Zone:Read` on the target zone, then:

```bash
kubectl create secret generic cloudflare-api-token \
  --namespace cert-manager \
  --from-literal=api-token=<TOKEN>
```

## Apply

Replace `${EMAIL}` in `cluster-issuer.yaml`, then:

```bash
kubectl apply -f cluster-issuer.yaml
```

## Why DNS-01

Works with internal services without public HTTP endpoints. Issues wildcard certs.
