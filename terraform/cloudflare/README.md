# Cloudflare DNS

DNS for `thelabdesk.com` as code, so a DNS change is a reviewable diff instead of a
dashboard click nobody remembers making.

## Why one wildcard record, not one per service

`*.k8s.thelabdesk.com` covers every k3s service (`argocd.k8s`, `grafana.k8s`,
`watch.k8s`, ...) with a single record. Routing to the right backend is Traefik's job
(via each app's `Ingress` hostname), not DNS's — the wildcard just needs to get a request
to the node.

## Why a LAN IP in a public DNS record

The record's content is the k3s node's private `192.168.100.0/24` address, not a public
one. Nothing is port-forwarded on the router (see
[../../docs/proxmox-host.md](../../docs/proxmox-host.md)'s security posture), so this
record only resolves to somewhere actually reachable from inside the LAN or over
Tailscale — a public DNS record pointing at a private IP is not the same thing as a
public attack surface.

## Setup

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in the real zone ID
export CLOUDFLARE_API_TOKEN='<token with Zone.DNS:Edit + Zone.Zone:Read>'
terraform init
terraform plan
terraform apply
```

The API token is never a Terraform variable — it's read from `CLOUDFLARE_API_TOKEN` by
the provider's own default lookup, so it never ends up in state or in a `.tfvars` file.

## State

Local state, gitignored, same as `*.tfvars`. This is a single-maintainer homelab — a
remote backend would be solving a problem (concurrent applies) that doesn't exist here.
