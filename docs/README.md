# Setup docs

How to bring this homelab up from scratch, in order — each guide is a linear,
copy-pasteable walkthrough of one stage.

| # | Guide | What it covers |
| - | ----- | -------------- |
| 1 | [proxmox-host.md](proxmox-host.md) | Install Proxmox VE, base setup (repos, updates, lid), access hardening (SSH key-only, firewall, 2FA), and Tailscale remote access |
| 2 | [k3s-vm.md](k3s-vm.md) | Create the Proxmox VM and install single-node k3s |

More stages (Argo CD bootstrap) are added here as they land. Security is designed
in at each step rather than retrofitted — see the reasoning inline in each guide.
