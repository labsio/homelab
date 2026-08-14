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

## Next

- Bootstrap cert-manager + Argo CD (see [../k8s/infrastructure](../k8s/infrastructure));
  the app-of-apps root then manages everything else.
