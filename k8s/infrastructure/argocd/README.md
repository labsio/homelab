# Argo CD

GitOps controller. Bootstrapped via Helm, exposed at `argocd.k8s.${DOMAIN}`.

## Install

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.7.6 \
  --set 'configs.params.server\.insecure=true'
```

## Apply ingress and certificate

Replace `${DOMAIN}` in `certificate.yaml` and `ingress.yaml`, then:

```bash
kubectl apply -k .
```

## Initial admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Delete the secret after first login.
