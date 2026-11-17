# Standing Cloudflare tunnel for the stomped.dev Melee bot (exphil,
# scripts/stomped_serve.exs). The arena opens a WebSocket to the URL a bot
# registers, so the URL has to outlive restarts: a quick tunnel
# (`cloudflared tunnel --url`) gets a new random trycloudflare.com host every
# run and had to be re-registered each time (2026-11). A named tunnel keeps
# one hostname, and this unit keeps it up from boot.
#
# Desktop only: the bot runs on the RTX 5090. Off until
# scripts/stomped-tunnel-setup.sh has created the tunnel and written
# ./stomped-tunnel.json (tunnel id + hostname; neither is a secret, the id
# alone cannot run the tunnel). The credentials stay outside the repo, root-
# only, at credentialsFile; the unit reads them through systemd LoadCredential.
#
# The tunnel forwards to localhost:port whether or not the bot is running;
# with the bot down Cloudflare answers 502 and the arena sees it offline.
{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.stompedTunnel;
  dataFile = ./stomped-tunnel.json;
  data = if builtins.pathExists dataFile then lib.importJSON dataFile else { };
in
{
  options.dotfiles.stompedTunnel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.dotfiles.profile == "desktop" && data != { };
      description = "Run the named Cloudflare tunnel for the stomped bot.";
    };
    tunnelId = lib.mkOption {
      type = lib.types.str;
      default = data.tunnelId or "";
      description = "Tunnel UUID from `cloudflared tunnel create`.";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = data.hostname or "";
      description = "Public hostname routed to the tunnel (`cloudflared tunnel route dns`).";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Local port stomped_serve.exs listens on (its --port, default 3000).";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/cloudflared/stomped.json";
      description = "Tunnel credentials JSON, root-only, outside the repo.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tunnelId != "" && cfg.hostname != "";
        message = "dotfiles.stompedTunnel needs tunnelId and hostname (run scripts/stomped-tunnel-setup.sh).";
      }
    ];

    services.cloudflared = {
      enable = true;
      # Keyed by UUID, not name: resolving a tunnel name needs the account
      # cert.pem, the UUID needs only the credentials file.
      tunnels.${cfg.tunnelId} = {
        credentialsFile = cfg.credentialsFile;
        ingress.${cfg.hostname} = "http://localhost:${toString cfg.port}";
        default = "http_status:404";
      };
    };

    # The CLI, for `cloudflared tunnel info` and re-routing DNS by hand.
    environment.systemPackages = [ pkgs.cloudflared ];
  };
}
