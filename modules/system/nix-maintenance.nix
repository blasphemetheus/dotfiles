{ pkgs, ... }:
{
  # Enable flakes and the new nix command
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # hyprwm's binary cache, so the flake Hyprland (+ hypr* deps) is substituted
  # instead of built from source. Merged with the default cache.nixos.org.
  nix.settings.substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];

  # trust devenv's binary cache and allow blewf to manage caches
  nix.settings.trusted-users = [
    "root"
    "blewf"
  ];

  # ── Store hygiene ────────────────────────────────────────────────────
  # / and /nix share one ext4 partition, so an ungroomed store eats $HOME.
  # GC weekly; keep 30d of generations so rollback still works.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # devenv memoizes evaluation results — including absolute /nix/store paths —
  # in <project>/.devenv/nix-eval-cache.db, but only GC-roots the newest shell
  # (.devenv/gc/shell, overwritten each rebuild). The sweep above deletes the
  # older paths the cache still references, after which devenv either dies with
  # "path '/nix/store/...-devenv-shell.drv' does not exist and cannot be
  # created" or silently serves a stale evaluation. Drop the caches so the next
  # devenv command re-evaluates; they are pure cache and cost ~1s to rebuild.
  systemd.services.nix-gc.postStop = ''
    ${pkgs.findutils}/bin/find /home/blewf -maxdepth 5 \
      \( -name node_modules -o -name .git -o -name .direnv -o -name result \) -prune -o \
      -type d -name .devenv -exec ${pkgs.coreutils}/bin/rm -f \
        {}/nix-eval-cache.db {}/nix-eval-cache.db-shm {}/nix-eval-cache.db-wal \;
  '';

  # Hardlink identical files in the store. auto-optimise-store dedups on every
  # build; the weekly timer sweeps what already accumulated.
  nix.settings.auto-optimise-store = true;
  nix.optimise.automatic = true;

  # nh — nicer rebuild UX (`nh os switch`, shows a diff of what changed).
  # Its own `clean` is left off; nix.gc above already handles collection.
  programs.nh = {
    enable = true;
    flake = "/home/blewf/dotfiles";
  };

}
