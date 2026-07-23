#!/usr/bin/env bash
# update-rwing.sh — bump the packaged rwing (SSB Melee replay viewer) to a new release.
#
# rwing is a paid, closed-source Patreon binary, so it can't be fetched automatically.
# When a new version drops:
#   1. Download the Linux build — the bare `rwing-linux-<version>` file (NOT the .deb / .rpm /
#      .pkg.tar.zst; those are for other distros) — from https://patreon.com/rwing_aitch
#   2. Run:  ~/dotfiles/scripts/update-rwing.sh ~/Downloads/rwing-linux-<version>
#   3. Then activate:  sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka
#
# It derives the version from the filename, computes the hash, registers the binary in the Nix
# store (requireFile source), patches pkgs/rwing.nix, stages it, and validates the build.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXFILE="$DOTFILES/pkgs/rwing.nix"

BIN="${1:-}"
if [[ -z "$BIN" || ! -f "$BIN" ]]; then
  echo "usage: $(basename "$0") <path-to-rwing-linux-VERSION>" >&2
  echo "  e.g. $(basename "$0") ~/Downloads/rwing-linux-a2.4" >&2
  exit 1
fi

base="$(basename "$BIN")"
if [[ "$base" != rwing-linux-* ]]; then
  echo "error: file must be named 'rwing-linux-<version>' (got '$base')." >&2
  echo "  The requireFile store name is derived from it — rename the download if needed." >&2
  exit 1
fi
version="${base#rwing-linux-}"

echo "==> version:  $version"
hash="$(nix hash file "$BIN")"
echo "==> hash:     $hash"

echo "==> registering binary in the Nix store (nix-store --add-fixed)…"
storepath="$(nix-store --add-fixed sha256 "$BIN")"

# The requireFile source is copied into rwing-unwrapped at build time, so it is NOT in the
# runtime closure — nothing roots it, and every `nix-collect-garbage` deletes it. That is
# silent until a rebuild is forced (version bump, editing rwing.nix, or a nixpkgs bump of a
# buildInput like gtk3), which then fails because the source is gone. Pin it with a GC root so
# it survives collection. Indirect root: gcroots/auto → this link → store path.
echo "==> pinning binary as a GC root (survives nix-collect-garbage)…"
gcroots="${XDG_STATE_HOME:-$HOME/.local/state}/nix/rwing-gcroots"
mkdir -p "$gcroots"
nix-store --add-root "$gcroots/$base" --indirect --realise "$storepath" >/dev/null

echo "==> patching $NIXFILE"
# Only the two single-source-of-truth lines at the top of the `let` block change.
sed -i -E \
  -e "s|^  version = \"[^\"]*\";|  version = \"$version\";|" \
  -e "s|^  hash = \"[^\"]*\";|  hash = \"$hash\";|" \
  "$NIXFILE"

# Flakes only see git-tracked files, so stage the change before building.
git -C "$DOTFILES" add pkgs/rwing.nix

echo "==> validating build (no activation)…"
nixos-rebuild build --flake "$DOTFILES#nixos_slanka"

cat <<EOF

✓ rwing $version is packaged and builds. Activate with:
    sudo nixos-rebuild switch --flake ~/dotfiles#nixos_slanka

Notes:
  • The binary is pinned as a GC root under \$XDG_STATE_HOME/nix/rwing-gcroots, so it now
    survives nix-collect-garbage. Old versions' roots there can be deleted once unused.
  • Commit pkgs/rwing.nix when ready (the binary itself is never committed).
EOF
