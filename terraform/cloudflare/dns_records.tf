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

# Reaching a service from outside the house without forwarding a port: the k3s
# node is on the tailnet, so this name resolves straight to its Tailscale
# address instead of its LAN one. An explicit record beats the wildcard above,
# which is the whole trick -- `home` stays on the LAN path, `home-ts` takes the
# tailnet path, and both are served by the same Traefik with the same
# certificate and the same basic auth.
#
# The address is public but unroutable: 100.64.0.0/10 is CGNAT space, so this
# answer is only useful to a device that is already authenticated to the
# tailnet. Nothing here grants access.
resource "cloudflare_dns_record" "home_ts" {
  zone_id = var.cloudflare_zone_id
  name    = "home-ts.k8s"
  type    = "A"
  content = "100.80.110.100"
  ttl     = 1
  proxied = false
  comment = "our-home over Tailscale (k8s-cp-1 tailnet address) - managed by Terraform"
}
