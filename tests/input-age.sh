#!/usr/bin/env bash
set -euo pipefail
filter=$1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cat > "$work/flake.lock" <<'JSON'
{
  "root": "root",
  "nodes": {
    "root": {"inputs": {
      "nixpkgs": "nixpkgs_3", "alias": ["nixpkgs"],
      "nested": ["tool", "nixpkgs"], "tool": "tool",
      "unknown": "local", "future": "future"
    }},
    "nixpkgs": {"locked": {"lastModified": 172800}},
    "nixpkgs_3": {"locked": {"lastModified": 0, "rev": "old-source"}},
    "tool": {"inputs": {"nixpkgs": ["nixpkgs"]}, "locked": {"lastModified": 86400}},
    "local": {"locked": {"type": "path"}},
    "future": {"locked": {"lastModified": 999999}}
  }
}
JSON
jq --argjson now 172800 -f "$filter" "$work/flake.lock" > "$work/before"
jq -e '
  (map(select(.input == "nixpkgs" or .input == "alias" or .input == "nested")) |
    length == 3 and all(.[]; .node == "nixpkgs_3" and .ageDays == 2)) and
  (map(select(.input == "unknown"))[0].ageDays == null) and
  (map(select(.input == "future"))[0].ageDays == 0)
' "$work/before"
# A checkout/touch must not reset source age.
touch -d '2030-01-01' "$work/flake.lock"
jq --argjson now 172800 -f "$filter" "$work/flake.lock" > "$work/after"
cmp "$work/before" "$work/after"
# Reject malformed and cyclic references instead of claiming they are fresh.
jq '.nodes.root.inputs.nixpkgs = ["nixpkgs"]' "$work/flake.lock" > "$work/cycle"
if jq --argjson now 172800 -f "$filter" "$work/cycle" >/dev/null 2>&1; then
  echo 'Cyclic follows unexpectedly accepted' >&2
  exit 1
fi
jq '.nodes.root.inputs.nixpkgs = "missing"' "$work/flake.lock" > "$work/missing"
if jq --argjson now 172800 -f "$filter" "$work/missing" >/dev/null 2>&1; then
  echo 'Missing node unexpectedly accepted' >&2
  exit 1
fi
