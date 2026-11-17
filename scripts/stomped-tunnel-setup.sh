#!/usr/bin/env bash
# One-time setup of the standing Cloudflare tunnel for the stomped bot
# (modules/system/stomped-tunnel.nix). Desktop only.
#
#   scripts/stomped-tunnel-setup.sh bot.example.com
#
# The hostname must be under a domain already on your Cloudflare account.
# Steps, each skipped when already done:
#   1. cloudflared tunnel login        (browser; writes ~/.cloudflared/cert.pem)
#   2. cloudflared tunnel create stomped
#   3. cloudflared tunnel route dns stomped HOSTNAME
#   4. install the credentials root-only at /etc/cloudflared/stomped.json (sudo)
#   5. write modules/system/stomped-tunnel.json and make it visible to the flake
#   6. a fixed bot path secret at ~/.config/stomped/path-secret
# Then it evaluates both hosts. Applying is yours: `nrs`, then commit the json.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

host=${1:?usage: $0 HOSTNAME (e.g. bot.example.com)}
name=stomped
creds=/etc/cloudflared/stomped.json
cf() { nix shell nixpkgs#cloudflared -c cloudflared "$@"; }

if [[ ! -f ~/.cloudflared/cert.pem ]]; then
    echo "== Log in to Cloudflare and pick the domain for $host"
    cf tunnel login
fi

id=$(cf tunnel list -o json | jq -r --arg n "$name" '.[] | select(.name == $n) | .id' | head -1)
if [[ -z "$id" ]]; then
    echo "== Creating tunnel $name"
    cf tunnel create "$name"
    id=$(cf tunnel list -o json | jq -r --arg n "$name" '.[] | select(.name == $n) | .id' | head -1)
fi
[[ -n "$id" ]] || { echo "could not find tunnel $name" >&2; exit 1; }
echo "== Tunnel $name is $id"

echo "== Routing $host to the tunnel"
cf tunnel route dns "$id" "$host" || echo "   (route dns failed; if $host already points at this tunnel that is fine)"

if sudo test -s "$creds"; then
    echo "== Credentials already at $creds"
else
    [[ -f ~/.cloudflared/$id.json ]] || { echo "missing ~/.cloudflared/$id.json (created on another machine?)" >&2; exit 1; }
    echo "== Installing credentials at $creds (root-only)"
    sudo install -D -m 600 -o root -g root ~/.cloudflared/"$id".json "$creds"
fi

printf '{\n  "tunnelId": "%s",\n  "hostname": "%s"\n}\n' "$id" "$host" > modules/system/stomped-tunnel.json
git add -N modules/system/stomped-tunnel.json

secret_file=~/.config/stomped/path-secret
if [[ ! -s $secret_file ]]; then
    mkdir -p "$(dirname "$secret_file")"
    (umask 077 && uuidgen > "$secret_file")
fi
secret=$(cat "$secret_file")

echo "== Evaluating both hosts"
./scripts/validate.sh

cat <<MSG

Done. Next:
  nrs                                   # apply; starts cloudflared-tunnel-$id
  git add modules/system/stomped-tunnel.json && git commit -m "stomped tunnel: $host"
  systemctl status cloudflared-tunnel-$id

Serve the bot with the fixed secret (from ~/git/exphil):
  mix run scripts/stomped_serve.exs --path-secret "\$(cat $secret_file)" \\
    --url "https://$host/\$(cat $secret_file)" --policy ...

Register this URL at https://stomped.dev/bots, once:
  https://$host/$secret
MSG
