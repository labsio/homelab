# Roadmap

Where this homelab is going, ordered by priority. The `What's next` section in
[README](README.md) is the short version; this file is the working list.

Effort: **S** small, **M** medium, **L** large. Items are grouped, and groups are
worked top to bottom — later groups assume the earlier ones are in place.

## Bring-up order — new server, from scratch

This host is a clean rebuild, so security is designed in from the first commit rather
than retrofitted later. Two decisions are fixed: access is **Tailscale-only** (no port
forwarding on the router, ever) and backups start **local, offsite later**. The thematic
groups below stay the reference for detail; this table is the order they are actually
done in on the new hardware. Status: `todo` / `wip` / `done`.

| # | Step | Why | Effort | Status |
| - | ---- | --- | ------ | ------ |
| 1 | Host base: minimal OS, `unattended-upgrades`, SSH key-only, no root login | The floor everything else stands on; kernel/runtime CVEs get patched without waiting for a free weekend | S | done |
| 2 | Tailscale for remote access; nothing forwarded on the router (LAN kept as a trusted second path) | Removes the whole internet-facing attack surface before a single service exists — the greenfield form of the "Access model" group | S | done |
| 3 | Pick secrets-as-code up front (SOPS + age) and keep a secret inventory as secrets are created | On a clean start, secrets can be encrypted-in-git from commit one instead of migrated later | M | todo |
| 4 | k3s + cert-manager + one Argo CD root `Application`; DNS-01 certs, hostnames resolve to Tailscale addresses | The single-owner GitOps foundation; DNS-01 still issues certs with no inbound ports | M | todo |
| 5 | `restic` local backups wired up *before* apps hold real data | The tooling and habit must exist before there is anything worth losing | M | todo |
| 6 | `test` namespace + disposable `k3d` flow | Validate every change off the always-on cluster | M | todo |
| 7 | Deploy apps hardened in their first manifest: `runAsNonRoot`, read-only rootfs, default-deny `NetworkPolicy`; `no-new-privileges` + dropped caps on the Compose side | On a rebuild these are the initial version of each service, not a later hardening pass | M | todo |
| 8 | Monitoring stack + external dead-man's switch + Loki retention/compaction | Observability you can trust once workloads run | M | todo |
| 9 | Renovate + CI gates (`gitleaks`, `kustomize build`) | Keep the pinned versions moving and stop a broken manifest at the PR, not the sync | M | todo |
| 10 | Offsite encrypted backup copy + monthly restore drill | A local-only copy does not survive fire, theft or ransomware | M | todo |

The grouped backlog below keeps the full detail and the "nice to have" tail.

## Foundation

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| One Argo CD root `Application` as the single source of truth, pointing at this repo only | GitOps needs exactly one owner per resource; two roots managing the same namespaces fight each other | S | — |
| A `test` namespace via Kustomize overlays, plus a disposable `k3d` flow for experiments | Validate a change before it reaches the always-on cluster | M | single root |
| Secret inventory: what exists, what reads it, where the source of truth is | Rebuilding a cluster should not depend on memory | S | — |

## Access model

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| Move all service access behind a WireGuard/Tailscale tunnel | A homelab does not need a public attack surface; DNS-01 certificates keep working without inbound ports | M | single root |
| No inbound ports on the router; internal DNS resolves services to tunnel addresses | Removes the entire class of internet-facing exposure instead of patching it | M | tunnel |
| Trust the Proxmox CA in Caddy instead of skipping certificate verification | Proxy hops should be verified end to end | S | tunnel |

## Backups

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| `restic` backups of Docker volumes, k3s PVCs, cluster state and Secrets to a local target | Git holds the description of the infrastructure, not the data | M | — |
| Offsite copy with client-side encryption | A copy in the same room does not survive fire, theft or ransomware | M | local backups |
| Monthly restore drill, documented; alert when a backup run is missed | A backup that was never restored is a hope, not a backup | M | offsite copy |

## Observability that can be trusted

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| Alert routing configuration fully in git, no per-cluster placeholders | A placeholder in git means either silent alerts or drift | S | — |
| External dead-man's switch watching the `Watchdog` alert | The cluster cannot tell you that the cluster is down | S | alert routing |
| Log retention and compaction for Loki; alerts on PVC and host disk usage | Unbounded log growth eventually takes the stack down with it | M | — |
| Metrics and logs from the Docker host into the same stack | Half the estate is currently outside the monitoring cluster | M | tunnel |
| Blackbox probes for every published service | Catch "the page is down" independently of internal metrics | S | — |

## Updates and supply chain

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| Renovate for Helm charts, container images and GitHub Actions | Everything is pinned; pins need something to raise them, or security patches never arrive | M | — |
| `gitleaks`, `kustomize build` and schema validation in CI, not only pre-commit | Local hooks can be bypassed; a broken manifest should fail the PR, not the sync | S | — |
| Unattended security upgrades on the hosts, with a documented maintenance window | Kernel and runtime CVEs do not wait for a free weekend | S | — |
| Bring cert-manager and Argo CD themselves under GitOps, so their versions move via PR | Bootstrap components installed by hand are the ones that go stale | L | Renovate |

## Hardening

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| Default-deny `NetworkPolicy` with explicit allows, including egress to the LAN | Without it, one compromised pod reaches everything, cluster and home network alike | M | — |
| PodSecurity labels, `ResourceQuota` and `LimitRange` per namespace | Blast-radius limits that cost nothing to add | S | — |
| `runAsNonRoot`, read-only root filesystem, no service-account token where unused | Finish the container hardening already started in the k8s manifests | S | — |
| Same hardening on the Compose side: `no-new-privileges`, dropped capabilities, read-only where possible | The headless browser that renders arbitrary websites deserves it most | M | — |

## Secrets as code

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| SOPS + age (or sealed-secrets) so Secrets live encrypted in git | Replaces the earlier External Secrets Operator + Azure Key Vault plan — same goal, no cloud dependency and no cost | M | secret inventory, backups |

## Nice to have

| Item | Why | Effort | Depends on |
| ---- | --- | ------ | ---------- |
| One wildcard certificate reflected into namespaces instead of one per namespace | The current pattern issues the same certificate several times over | M | — |
| Image digests instead of mutable tags | A tag can be republished; a digest cannot | S | Renovate |
| Replace the deprecated `loki-stack` chart with `loki` + Grafana Alloy | The current chart is deprecated upstream | M | backups |
| Ansible bootstrap: one command to bring up a fresh node | The stated end goal of this repo | L | secrets as code |
| Migrate FreshRSS and changedetection from Compose to k3s | One platform instead of two — after backups exist, since it moves live data | L | restore drill |
| Real contact address in the ACME issuer; document why monitoring syncs manually | Small things that cost an afternoon each and remove future confusion | S | — |
