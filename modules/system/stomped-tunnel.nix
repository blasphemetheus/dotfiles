# Public endpoint for the stomped.dev Melee bot (exphil,
# scripts/stomped_serve.exs, listening on 127.0.0.1:port). The arena opens a
# WebSocket to the URL a bot registers, so the URL must outlive restarts and
# add as little latency as possible: at lead 7 the bot has about 94 ms for the
# whole round trip. Desktop only (the bot runs on the RTX 5090). Settings come
# from ./stomped-tunnel.json; with no such file everything here is off.
#
# Two ways to expose it, chosen by `exposure`:
#
# direct (preferred): the router forwards TCP 80 and 443 to this machine, the
#   DNS record for `hostname` is DNS-only (grey cloud) and points at the home
#   IP, and Caddy terminates TLS (Let's Encrypt, renewed by itself) and proxies
#   to the bot. cloudflare-dyndns keeps the A record on the home IP; it needs a
#   Cloudflare API token (Zone:DNS:Edit on the zone) root-only at
#   apiTokenFile. Port 80 is open only for the ACME challenge and the redirect.
#
# tunnel: a named Cloudflare tunnel (cloudflared). No router change and no
#   public home IP, but on 2026-11-17 Cloudflare served the free-plan zone
#   from Atlanta while the tunnel connected in Chicago, and the arena's
#   round trip went from 55-60 ms (quick tunnel, served from Chicago) to
#   100-111 ms: 95% of pads late. Kept as the fallback.
#
# With the bot down, both answer 502 and the arena sees it offline.
{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.stompedTunnel;
  dataFile = ./stomped-tunnel.json;
  data = if builtins.pathExists dataFile then lib.importJSON dataFile else { };
  origin = "127.0.0.1:${toString cfg.port}";
in
{
  options.dotfiles.stompedTunnel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.dotfiles.profile == "desktop" && data != { };
      description = "Expose the stomped bot at a fixed public hostname.";
    };
    exposure = lib.mkOption {
      type = lib.types.enum [ "direct" "tunnel" ];
      default = data.exposure or "tunnel";
      description = "direct: port forward + Caddy TLS. tunnel: named Cloudflare tunnel.";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = data.hostname or "";
      description = "Public hostname of the bot.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Local port stomped_serve.exs listens on (its --port, default 3000).";
    };
    tunnelId = lib.mkOption {
      type = lib.types.str;
      default = data.tunnelId or "";
      description = "Tunnel UUID from `cloudflared tunnel create` (tunnel exposure).";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/cloudflared/stomped.json";
      description = "Tunnel credentials JSON, root-only, outside the repo (tunnel exposure).";
    };
    apiTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/stomped/cloudflare-dns-token";
      description = "Cloudflare API token for the dynamic A record, root-only (direct exposure).";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.hostname != "";
          message = "dotfiles.stompedTunnel needs a hostname (modules/system/stomped-tunnel.json).";
        }
      ];
    }

    (lib.mkIf (cfg.exposure == "direct") {
      services.caddy = {
        enable = true;
        # Caddy proxies WebSockets as they are; flush_interval -1 also stops it
        # buffering the plain HTTP responses (ping, handshake).
        virtualHosts.${cfg.hostname}.extraConfig = ''
          reverse_proxy ${origin} {
            flush_interval -1
          }
        '';
      };

      networking.firewall.allowedTCPPorts = [ 80 443 ];

      # Home IPs change rarely but do change; keep the DNS-only A record on it.
      services.cloudflare-dyndns = {
        enable = true;
        apiTokenFile = cfg.apiTokenFile;
        domains = [ cfg.hostname ];
        proxied = false;
        ipv4 = true;
        # The router hands out only private IPv6 (NAT66), so no AAAA record.
        ipv6 = false;
      };
    })

    (lib.mkIf (cfg.exposure == "tunnel") {
      assertions = [
        {
          assertion = cfg.tunnelId != "";
          message = "tunnel exposure needs tunnelId (run scripts/stomped-tunnel-setup.sh).";
        }
      ];

      services.cloudflared = {
        enable = true;
        # Keyed by UUID, not name: resolving a tunnel name needs the account
        # cert.pem, the UUID needs only the credentials file.
        tunnels.${cfg.tunnelId} = {
          credentialsFile = cfg.credentialsFile;
          # 127.0.0.1, not localhost: cloudflared resolved localhost to [::1]
          # first, while stomped_serve.exs binds IPv4 loopback only, so most
          # requests failed with 502 "dial tcp [::1]:3000" (2026-11-17).
          ingress.${cfg.hostname} = "http://${origin}";
          default = "http_status:404";
        };
      };

      # The CLI, for `cloudflared tunnel info` and re-routing DNS by hand.
      environment.systemPackages = [ pkgs.cloudflared ];
    })
  ]);
}
