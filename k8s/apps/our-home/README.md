# our-home

Ingress for a personal application that runs **on the node itself**, not in the
cluster. The application and its data are private and live outside this
repository; what is here is only the routing in front of it.

`home.k8s.thelabdesk.com` -> Traefik -> basic auth -> `192.168.100.11:8000`

## Why there is no Deployment

The application is a systemd *user* service on `k8s-cp-1` that owns a SQLite
database on local disk. The node and the cluster are the same machine, so
putting it in a pod would only add a PVC and a migration without changing where
the bytes actually are.

Kubernetes models this with a Service that has **no selector**, plus an
`EndpointSlice` naming the node's address. Traefik then treats it like any
other backend, which is the whole point: it gets the wildcard certificate, the
same ingress path, and the same middleware as everything else.

The `kubernetes.io/service-name` label on the EndpointSlice is what binds it to
the Service. Without it the Service has no endpoints and every request is a 503.

## Authentication is not optional here

The application has none of its own and accepts writes on unauthenticated POST
endpoints, so the Traefik `basicAuth` middleware is the only thing in front of
it. The credentials are **not** in git:

```bash
htpasswd -nbB <user> '<password>' > /tmp/auth      # bcrypt
kubectl -n our-home create secret generic our-home-basic-auth \
  --from-file=users=/tmp/auth
shred -u /tmp/auth
```

Traefik expects the htpasswd lines under a key named `users`.

A mistyped middleware reference in the Ingress annotation **fails open** —
Traefik serves the route with no middleware at all rather than erroring. After
any rename, confirm the front door is still shut:

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://home.k8s.thelabdesk.com/   # 401
```

## Exposure

Nothing is port-forwarded on the router. `*.k8s.thelabdesk.com` resolves to a
LAN address, so this name is reachable from the LAN, and from the tailnet only
once a subnet router advertises `192.168.100.0/24`.
