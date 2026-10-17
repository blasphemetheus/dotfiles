#!/usr/bin/env bash
# Evaluate both complete host configurations and run the lightweight checks.
# --build additionally builds both complete systems, without switching either.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
build=false
case "${1:-}" in
    '') ;;
    --build) build=true ;;
    *) echo "Usage: $0 [--build]" >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then echo 'Too many arguments' >&2; exit 2; fi

for host in nixos_slanka aspire; do
    echo "Evaluating $host"
    nix eval --no-write-lock-file --raw ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath"
    echo
done
nix flake check --no-write-lock-file --print-build-logs

if "$build"; then
    nix build --no-write-lock-file --no-link --print-build-logs \
        '.#nixosConfigurations.nixos_slanka.config.system.build.toplevel' \
        '.#nixosConfigurations.aspire.config.system.build.toplevel'
fi
