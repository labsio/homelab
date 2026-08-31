# DNS records for thelabdesk.com managed by Terraform.
#
# One wildcard record covers every k3s service (argocd, grafana, watch, ...) rather than
# one explicit record per service — Ingress hostnames are what actually route traffic
# inside the cluster, so the DNS side only needs to get any *.k8s.thelabdesk.com request
# to the node. The content is the k3s node's LAN IP, not a public one — nothing is
# port-forwarded on the router, so this record only resolves to somewhere reachable from
# inside the LAN or over Tailscale, never from the open internet.
resource "cloudflare_dns_record" "wildcard_k8s" {
  zone_id = var.cloudflare_zone_id
  name    = "*.k8s"
  type    = "A"
  content = "192.168.100.11"
  ttl     = 1
  proxied = false
  comment = "All k3s services (argocd, grafana, watch, ...) - managed by Terraform"
}
