# Proxmox host setup

Step 1 of bringing up the homelab (see the *Bring-up order* in
[ROADMAP.md](../ROADMAP.md)). It turns a spare machine into the Proxmox VE
hypervisor and hardens it **before** anything else runs on it.

Reference host: an old laptop — single disk, wired Ethernet, 32 GB RAM,
Proxmox VE 9 on Debian 13 (trixie).

## What you need

- A spare x86-64 machine. **The whole disk is erased — back up first.**
- **Wired Ethernet.** Wi-Fi does not bridge cleanly for VMs; use a cable or a
  USB-Ethernet adapter.
- A USB stick and a second computer to write it and reach the web UI.
- A static IP for the host, outside the router's DHCP pool.

### Network plan

| What | Value |
| ---- | ----- |
| Subnet | `192.168.100.0/24` |
| Gateway / router | `192.168.100.1` |
| Proxmox host | `192.168.100.10` |
| DHCP pool | `.100`–`.199` (host `.10` sits outside it) |

## 1. Install Proxmox VE

1. Download the Proxmox VE ISO from <https://www.proxmox.com/downloads> and
   verify its SHA-256 and GPG signature before use.
2. Write it to the USB stick (`dd`, balenaEtcher, or Rufus in DD mode).
3. In BIOS/UEFI: enable virtualization (VT-x/AMD-V + VT-d/IOMMU), set
   **power-on after AC loss** so the host restarts itself after an outage,
   disable Secure Boot, and boot from the USB.
4. In the installer:
   - Target disk: the single internal disk, filesystem **ext4** (LVM). One disk
     has no redundancy either way, so ZFS buys little here — keep it simple.
   - Timezone, a strong `root` password, and a **real admin email** (used for
     alerts later).
   - **Management Network:** pick the wired NIC, FQDN `pve.homelab.lan`, address
     `192.168.100.10/24`, gateway `192.168.100.1`, DNS `192.168.100.1`.
5. Reboot, remove the USB. The web UI is at <https://192.168.100.10:8006>
   (`root@pam`, self-signed certificate warning is expected).

## 2. First boot — base

Log in over SSH or the console as `root`.

### 2.1 Repositories (no subscription)

PVE 9 / Debian 13 uses the deb822 `.sources` format. The enterprise repo needs a
paid subscription; while it is active `apt update` fails with 401 and **no
updates arrive at all**. Disable it and add the free no-subscription repo.

```bash
# disable the two enterprise repos
for f in pve-enterprise ceph; do
  echo "Enabled: false" >> /etc/apt/sources.list.d/$f.sources
done

# add the free no-subscription repo
cat > /etc/apt/sources.list.d/pve-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt update
apt -o Dpkg::Options::=--force-confold full-upgrade
```

If the kernel was upgraded, reboot to run it (`uname -r` before/after).

### 2.2 Automatic security updates

So kernel/openssl/ssh CVEs get patched without you chasing them.

```bash
apt install -y unattended-upgrades powermgmt-base
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
```

Scope is **Debian security only** — Proxmox packages are upgraded by hand, since
platform jumps deserve a human. Auto-reboot is off (kernels are rebooted
deliberately). `powermgmt-base` makes it skip runs while on battery, so an
upgrade never gets cut off mid-way during a power outage.

### 2.3 Laptop: don't sleep on lid close

Without this the server suspends the moment the lid shuts.

```bash
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/10-homelab-lid.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF
systemctl restart systemd-logind
```

## 3. Harden access

### 3.1 SSH: key-only

Copy your key up first (from your workstation), then disable password login so
brute-force is impossible:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.100.10   # once, from the client
```

```bash
# on the host
cat > /etc/ssh/sshd_config.d/10-homelab-hardening.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
EOF
sshd -t && systemctl reload ssh          # validate before reload — a bad config won't drop you
```

Verify from the client that the key still works and the password path is refused
(`Permission denied (publickey)`). The physical console stays as a fallback.

### 3.2 Firewall (default-deny)

The Proxmox firewall drops all inbound except an explicit allow-list. Only SSH,
the web UI, and ping are opened, and only from the LAN.

```bash
cat > /etc/pve/firewall/cluster.fw <<'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source 192.168.100.0/24 -p tcp -dport 22 -log nolog
IN ACCEPT -source 192.168.100.0/24 -p tcp -dport 8006 -log nolog
IN ACCEPT -source 192.168.100.0/24 -p icmp -log nolog
EOF
pve-firewall compile   # validate, then it applies
```

> **Enabling a firewall over SSH is how people lock themselves out.** Arm a
> dead-man's rollback first, so access is restored automatically if a rule is
> wrong:
> ```bash
> systemd-run --on-active=300 --unit=fw-deadman \
>   /bin/sh -c 'sed -i "s/^enable: 1/enable: 0/" /etc/pve/firewall/cluster.fw; pve-firewall restart'
> ```
> Verify a **new** SSH session and port 8006 still work, then cancel it:
> `systemctl stop fw-deadman.timer`.

### 3.3 Two-factor auth for `root@pam`

In the web UI: **Datacenter → Permissions → Two Factor → Add → TOTP**, scan the
QR with an authenticator app, confirm a code. If the authenticator is ever lost,
clear it from the console: `pveum user tfa delete root@pam`.

## 4. Remote access — Tailscale

Tailscale gives access from anywhere without forwarding any port on the router — it
connects out to your tailnet. Install and bring it up on the host:

```bash
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list
apt update && apt install -y tailscale
tailscale up --hostname=pve      # open the printed URL to authenticate the node
```

Then allow management over the tailnet in the firewall, keeping the LAN rules:

```
# add to [RULES] in /etc/pve/firewall/cluster.fw
IN ACCEPT -source 100.64.0.0/10 -p tcp -dport 22 -log nolog
IN ACCEPT -source 100.64.0.0/10 -p tcp -dport 8006 -log nolog
IN ACCEPT -source 100.64.0.0/10 -p icmp -log nolog
```

The host now answers on its tailnet address (`tailscale ip -4`). Proxmox always keeps the
local subnet in its built-in `management` IPSet, so the LAN stays reachable too — fine on a
trusted network, and not worth fighting the platform to force tunnel-only.

## Security posture

- **No inbound port-forwarding on the router.** Management (`8006`/`22`) is reachable from
  the LAN and over Tailscale, never from the internet.
- `root@pam` is protected by a key (SSH) and TOTP (web UI); the console is the
  break-glass fallback.

## Next

- Create the k3s VM that hosts the cluster.
