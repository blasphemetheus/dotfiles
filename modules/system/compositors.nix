# Shared graphical sessions, compositor plugins, and display integration.
{
  config,
  pkgs,
  inputs,
  ...
}:
let
  # dwl autostart + dwlb bar; run as dwl's `-s` child so it inherits
  # WAYLAND_DISPLAY and drains the status stream (see dwl/startup.sh).
  dwlStartup = pkgs.writeShellScript "dwl-startup" (builtins.readFile ../../dwl/startup.sh);

in
{
  hardware.graphics.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable Hyprland — compositor and matching portal from the upstream flake
  # (see flake.nix), not nixpkgs. nixpkgs lags the compositor and dropped
  # hyprexpo; pulling from the flake keeps compositor + plugins on one ABI.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # NixOS grants CAP_SYS_NICE through an ELF-only security wrapper. The
    # pinned upstream package uses a shell launcher; use a native launcher
    # while preserving its runtime PATH and the compositor/plugin ABI.
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland.override {
      makeWrapper = pkgs.makeBinaryWrapper;
    };
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Hyprland plugins. Stable /etc paths so the Lua config can hl.plugin.load()
  # them without hardcoding nix store paths. Both are built against the flake
  # Hyprland (flake.nix inputs) so their ABI matches 0.56.2.
  #   hyprsplit — dwm-style per-monitor workspace sets (Super+N = Nth workspace
  #               of the FOCUSED monitor; second monitor's set is ids 11-20).
  #   hyprexpo  — expo grid overview (sandwichfarm fork flake input).
  # hyprsplit is a Lua LIBRARY since Hyprland 0.55 (the .so refuses Lua configs):
  # install the pinned input's init.lua where hypr/.config/hypr/hyprsplit/init.lua
  # symlinks to, and lua/plugins.lua require()s it.
  environment.etc."hypr/hyprsplit/init.lua".source = "${inputs.hyprsplit}/init.lua";
  environment.etc."hypr/plugins/libhyprsplit.so".source = "${
    inputs.hyprsplit.packages.${pkgs.stdenv.hostPlatform.system}.hyprsplit
  }/lib/libhyprsplit.so";
  # hyprexpo from the fork's flake since v0.56.1+3 (built against our pinned
  # Hyprland via `follows`); pkgs/hyprexpo.nix was the 0.55-era hand-build.
  environment.etc."hypr/plugins/libhyprexpo.so".source = "${
    inputs.hyprexpo.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
  }/lib/libhyprexpo.so";

  # ── Alternative compositors, selectable at the greetd session picker ──
  # Purely additive: Hyprland stays the default. Log out and pick one to try it.
  #   niri  — scrollable tiling (infinite horizontal strip), Rust
  #   river — dynamic tiling, Zig, i3-ish tags
  #   dwl   — suckless dwm for Wayland (minimal; no session file upstream)
  programs.niri.enable = true;
  programs.river-classic.enable = true;

  # dwl ships no wayland-session entry, so provide one. providedSessions is
  # required by the sessionPackages assertion.
  services.displayManager.sessionPackages = [
    (pkgs.writeTextFile {
      name = "dwl-session";
      destination = "/share/wayland-sessions/dwl.desktop";
      text = ''
        [Desktop Entry]
        Name=dwl
        Comment=dwm for Wayland
        Exec=dwl -s ${dwlStartup}
        Type=Application
      '';
      passthru.providedSessions = [ "dwl" ];
    })
  ];

  # Keep GNOME as a fallback desktop environment
  services.desktopManager.gnome.enable = true;
  # GNOME drags in the LocalSearch/Tracker file indexer, which timed out on
  # D-Bus activation (120s) every Hyprland session. Not wanted here.
  services.gnome.localsearch.enable = false;
  services.gnome.tinysparql.enable = false;
  # avahi is up (via GNOME) but warned "No NSS support for mDNS"; wire nss-mdns
  # so .local names resolve and the warning goes away.
  services.avahi.nssmdns4 = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Cursor theme
  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  # Re-evaluate hyprshade schedule on resume from suspend/hibernate.
  # `exec-once = hyprshade auto` only fires at Hyprland startup, so a wake
  # that crosses 19:00 / 06:00 leaves the filter stuck in its pre-sleep state.
  # (Window is 19:00-06:00 per hypr/.config/hypr/hyprshade.toml.)
  systemd.services.hyprshade-resume = {
    description = "Re-apply hyprshade schedule after wake from suspend/hibernate";
    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = config.dotfiles.user.name;
      Environment = [ "XDG_RUNTIME_DIR=/run/user/${toString config.dotfiles.user.uid}" ];
      # Do NOT pick the instance by mtime (`ls -t`): Hyprland leaves the runtime
      # dir behind when an instance dies, and those stale dirs get touched later
      # than the live one, so `ls -t | head -1` reliably picks a DEAD instance.
      # `hyprctl instances` lists only compositors that are actually running.
      ExecStart = pkgs.writeShellScript "hyprshade-resume" ''
        sig=$(${config.programs.hyprland.package}/bin/hyprctl instances 2>/dev/null \
              | sed -n 's/^instance \(.*\):$/\1/p' | head -n1)
        [ -z "$sig" ] && exit 0
        export HYPRLAND_INSTANCE_SIGNATURE="$sig"
        exec ${pkgs.hyprshade}/bin/hyprshade auto
      '';
    };
  };

}
