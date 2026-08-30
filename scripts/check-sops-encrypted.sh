#!/usr/bin/env bash
# Pre-commit hook: refuse a *.enc.yaml file that isn't actually SOPS-encrypted
# (i.e. named like a secret but missing the `sops:` metadata block SOPS appends).
set -euo pipefail

status=0
for f in "$@"; do
  if ! grep -q "^sops:" "$f"; then
    echo "not SOPS-encrypted: $f"
    status=1
  fi
done
exit "$status"
