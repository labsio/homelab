# Secrets as code: SOPS + age

Every app README so far says the same thing: secrets are created out-of-band with
`kubectl create secret`, never committed. That works, but it means the cluster's secret
state lives only in the cluster — rebuild the cluster and you're reconstructing secrets
from memory (or a private notes file). This closes that gap: secrets get encrypted **into**
git instead of kept out of it, so `git clone` + decrypt is enough to reproduce them.

## The two keys

[age](https://github.com/FiloSottile/age) is a modern, simple file-encryption tool. A
keypair has two halves with very different handling rules:

| Key | Looks like | Where it lives | What it's for |
| --- | ---------- | --------------- | -------------- |
| Public | `age1...` | Committed in `.sops.yaml` | Tells SOPS who to encrypt *for* — safe to share, safe in git |
| Private | `AGE-SECRET-KEY-1...` | `~/.config/sops/age/keys.txt`, backed up outside this machine | Decrypts — **never** commit this, ever |

[SOPS](https://github.com/getsops/sops) (Secrets OPerationS) is the layer on top: it reads
`.sops.yaml`, encrypts the values in a file against the listed age public key(s), and can
decrypt again given the matching private key. Losing the private key with no backup makes
every secret ever encrypted with it permanently unrecoverable — there is no recovery path,
by design. (Losing the workstation without a backup of `keys.txt` is the realistic way this
happens — hence backing it up before it's used for anything real.)

## What `.sops.yaml` actually does

```yaml
creation_rules:
  - path_regex: .*\.enc\.ya?ml$
    encrypted_regex: ^(data|stringData)$
    age: age1meh4lt07w8kfekmu3jk7qefwru00446rxa4f0v8le5nv3ql82g2qdu6zcv
```

Two things worth noticing, because both are easy to get wrong:

- **`path_regex` matches on the filename, not the content.** SOPS doesn't know or care that
  a file is a Kubernetes `Secret` — it just encrypts any file named `*.enc.yaml` or
  `*.enc.yml`. The naming convention is what keeps it obvious in a directory listing or PR
  diff which files hold ciphertext.
- **`encrypted_regex` scopes encryption to specific *keys* within the file, not the whole
  file.** A Kubernetes Secret's `apiVersion`, `kind`, and `metadata` (including its `name`)
  stay in plaintext; only `data`/`stringData` get encrypted. That's deliberate — a reviewer
  can still see *which* secret a PR touches without being able to read its value.

## Day to day

```bash
sops --encrypt --in-place path/to/some-secret.enc.yaml   # after writing plaintext data/stringData
sops path/to/some-secret.enc.yaml                          # opens decrypted in $EDITOR, re-encrypts on save
sops --decrypt path/to/some-secret.enc.yaml                # print decrypted, e.g. to pipe into kubectl
```

A pre-commit hook (`sops-encrypted` in `.pre-commit-config.yaml`) refuses to commit any
`*.enc.yaml` file that isn't actually SOPS-encrypted (checks for the `sops:` metadata block
SOPS appends) — a plaintext file that happens to be named like an encrypted one is exactly
the mistake this naming convention could otherwise invite.

## What's not wired up yet

Encrypting a file is only half the story — something still has to **decrypt it into the
cluster**. That piece (a Kustomize `ksops` generator or an Argo CD Config Management
Plugin, evaluated when there's an actual secret to encrypt) lands with the cluster
bootstrap in [cluster-bootstrap.md](cluster-bootstrap.md), starting with
`cloudflare-api-token`. Until then, this doc covers the git-side half: keys exist, the
convention is decided, nothing is encrypted yet because nothing needs to be.
