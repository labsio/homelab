# k3s VM

The stage after the Proxmox host: a single VM that runs the k3s cluster. Run the
`qm` commands on the Proxmox host; the k3s install on the VM.

## Create the VM

Download the Ubuntu 24.04 cloud image once, then build a cloud-init VM — 4 vCPU,
8 GB RAM, 40 GB disk, static IP, key-only `ubuntu` user:

```bash
IMG=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
wget -qO "$IMG" https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qm create 100 --name k8s-cp-1 --memory 8192 --cores 4 --cpu host --onboot 1 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --ostype l26 --agent enabled=1
qm set 100 --scsi0 local-lvm:0,import-from="$IMG"
qm set 100 --ide2 local-lvm:cloudinit
qm set 100 --boot order=scsi0 --serial0 socket --vga serial0
qm resize 100 scsi0 40G
qm set 100 --ciuser ubuntu --sshkeys ~/id_ed25519.pub \
  --ipconfig0 ip=192.168.100.11/24,gw=192.168.100.1 --nameserver 1.1.1.1
qm start 100
```

`--sshkeys` takes a public-key file, so `ubuntu` is reachable by key only.

## Install k3s

Single node (server + agent). Keep the defaults — the Traefik ingress and the
`local-path` storage class are what the manifests in [../k8s](../k8s) expect.

```bash
ssh ubuntu@192.168.100.11
curl -sfL https://get.k3s.io | sudo sh -s - --write-kubeconfig-mode 644
sudo k3s kubectl get nodes        # k8s-cp-1 -> Ready
```

## Harden the node

The Ubuntu cloud image + cloud-init already leaves password auth off, pubkey auth on, swap
off, and a persistent journal — verify with `sshd -T` / `swapon --show` before assuming so.
What's left: fail2ban, finishing the SSH drop-in, and a UFW ruleset that doesn't break pod
networking.

```bash
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get install -y fail2ban
sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd
[sshd]
enabled = true
port    = ssh
EOF
sudo systemctl enable --now fail2ban

echo "PermitRootLogin no" | sudo tee /etc/ssh/sshd_config.d/99-hardening.conf
sudo sshd -t && sudo systemctl reload ssh   # validate before reload, same rule as the host
```

**UFW needs k8s-aware rules, not a plain deny-all** — the standard "SSH only" ruleset kills
flannel/pod networking, because pod traffic crosses the `FORWARD` chain, which UFW defaults
to `DROP`. k3s's defaults are pod CIDR `10.42.0.0/16` and service CIDR `10.43.0.0/16`
(confirm with `kubectl -n kube-system get svc kube-dns`):

```bash
sudo ufw allow 22/tcp    comment 'SSH'
sudo ufw allow 6443/tcp  comment 'k8s API'
sudo ufw allow 80/tcp    comment 'HTTP ingress'
sudo ufw allow 443/tcp   comment 'HTTPS ingress'
sudo ufw allow 8472/udp  comment 'flannel VXLAN'
sudo ufw allow 10250/tcp comment 'kubelet'
sudo ufw allow from 10.42.0.0/16 comment 'k3s pod CIDR'
sudo ufw allow from 10.43.0.0/16 comment 'k3s service CIDR'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw --force enable && sudo ufw reload
sudo ufw status verbose        # expect: Default: deny (incoming), allow (routed)
```

Verify immediately, before trusting it — a throwaway pod must resolve DNS through the
firewall:

```bash
kubectl run dnstest --rm -i --restart=Never --image=busybox:1.36 -- \
  nslookup kubernetes.default.svc.cluster.local    # must return 10.43.0.1
```

If DNS fails or pods crash-loop: `sudo ufw disable` (port 22 stays open regardless) and
re-check the CIDRs/forward policy. `qm terminal <id>` from the Proxmox host is the fallback
console if SSH itself is ever the thing that breaks.

Finish with a deliberate reboot — the real test of a firewall/service change is whether it
survives a restart:

```bash
sudo reboot
# reconnect after ~15s:
for s in k3s fail2ban ssh ufw; do echo "$s: $(systemctl is-active $s)"; done   # all active
kubectl get nodes                                                              # Ready
```

## Next

- Bootstrap cert-manager + Argo CD (see [../k8s/infrastructure](../k8s/infrastructure));
  the app-of-apps root then manages everything else.
