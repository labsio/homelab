# Cluster bootstrap

After [k3s-vm.md](k3s-vm.md) the node is up but empty. This brings the GitOps
platform online: cert-manager, Argo CD, and the app-of-apps that manages everything
else. Run the commands from the repo root with `KUBECONFIG` pointing at the cluster
(`export KUBECONFIG=/etc/rancher/k3s/k3s.yaml`).

The bootstrap layer under [../k8s/infrastructure](../k8s/infrastructure) is applied by
hand exactly once — Argo CD can't manage itself before it exists. From then on changes
flow through git.

## 1. cert-manager

Pinned chart version and the token secret details are in
[../k8s/infrastructure/cert-manager/README.md](../k8s/infrastructure/cert-manager/README.md).

```bash
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
  --version v1.18.2 --set crds.enabled=true --wait
kubectl create secret generic cloudflare-api-token -n cert-manager \
  --from-literal=api-token=<CLOUDFLARE_TOKEN>          # Zone.DNS:Edit + Zone.Zone:Read
kubectl apply -f k8s/infrastructure/cert-manager/cluster-issuer.yaml
kubectl get clusterissuer letsencrypt-prod            # Ready=True once the ACME account registers
```

## 2. Argo CD

```bash
helm install argocd argo/argo-cd -n argocd --create-namespace \
  --version 7.7.6 --set 'configs.params.server\.insecure=true' --wait
kubectl apply -k k8s/infrastructure/argocd            # ingress + wildcard Certificate
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d          # initial admin password; delete the secret after login
```

## 3. Root app-of-apps

```bash
kubectl apply -f k8s/argocd-apps/root.yaml
kubectl -n argocd get applications
```

The root Application (auto-sync, prune, self-heal) now owns everything in
`k8s/argocd-apps/`. The monitoring Applications are manual-sync on purpose — sync
them from the Argo CD UI when ready.

## Per-app secrets

Apps read secrets created out of band, never committed. Each app's README has the exact
`kubectl create secret` command.

| Secret | Namespace | For |
| ------ | --------- | --- |
| `cloudflare-api-token` | `cert-manager` | DNS-01 challenges |
| `grafana-admin` | `monitoring` | Grafana admin login |
| `telegram-bot-token` | `monitoring` | AlertManager → Telegram |

A pod stuck in `CreateContainerConfigError` usually means its secret isn't there yet.
