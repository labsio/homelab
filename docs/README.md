# Setup docs

How to bring this homelab up from scratch, in order — each guide is a linear,
copy-pasteable walkthrough of one stage.

| # | Guide | What it covers |
| - | ----- | -------------- |
| 1 | [proxmox-host.md](proxmox-host.md) | Install Proxmox VE on the host, then base setup (repos, updates, lid) and access hardening (SSH key-only, firewall, 2FA) |

More stages (Tailscale, the k3s VM, Argo CD bootstrap) are added here as they
land. Security is designed in at each step rather than retrofitted — see the
reasoning inline in each guide.
