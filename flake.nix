{
  description = "NixOS + Home Manager config (hosts: nixos_slanka desktop, aspire laptop)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AGS v3 (gnim) — nixpkgs only ships v2.3, whose `astal` lib API predates
    # the ags/gtk3+createPoll style this repo's widgets use.
    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.astal.follows = "astal";
    };

    # Hyprland straight from upstream. nixpkgs lags the compositor (shipped 0.53
    # plugins against a 0.54 hyprland) and, as of the 0.55 cycle, DROPPED
    # hyprexpo entirely. Pinning the release tag lets every plugin below follow
    # this exact build so their ABI matches — no per-plugin version chasing.
    # Deliberately NOT following our nixpkgs: that keeps hyprwm's cachix
    # (hyprland.cachix.org, added in configuration.nix) usable instead of
    # source-building the whole hypr* stack.
    # v0.56.2: fixes the aquamarine output-teardown SEGV (DP-2 deep-sleep link
    # flap at DPMS wake crashed 0.55.4 into safe mode 3x, 2026-08-01..10).
    #
    # nixpkgs pin: the tag's own lock (2026-08-04) has glaze 8.0.0, but its
    # CMake demands glaze 7.x (`find_package(glaze 7...<8)`) — find_package
    # fails, FetchContent tries to git-clone in the sandbox, build dies.
    # Upstream shipped the tag broken. Pin hyprland's nixpkgs to the last
    # nixos-unstable channel rev with glaze 7.9.1 (pre-8.0.0 bump of Aug 3).
    # This forfeits hyprland.cachix.org substitution (different drv hashes),
    # but the cache was already useless for this tag. Drop this pin (and the
    # nixpkgs-hypr input) at the next hyprland bump if upstream's lock is fixed.
    nixpkgs-hypr.url = "github:NixOS/nixpkgs/cd017c33bbf56d9d918cb6d21b3118acb4cee58d";
    # TEMP OVERRIDE 2026-08-30: v0.56.2 did NOT fully fix the DP-2 wake crash —
    # crash #4 (Aug 30) SEGV'd inside aquamarine 0.14.0 CBackend::dispatchIdle
    # (stale idle callback after output teardown). aquamarine v0.15.0
    # (2026-08-29) carries the connector-sequencing/idle-frame fixes, but no
    # Hyprland tag pairs with it yet, so override just hyprland's aquamarine.
    # Hyprland 0.56.2 only demands aquamarine>=0.9.3, and its hyprutils 0.14.0
    # satisfies aquamarine's >=0.8.0 (shared via the follows below, so exactly
    # one hyprutils ends up in the process). Drop this input + both follows at
    # the next Hyprland tag bump (>=0.57), which will lock aquamarine 0.15+
    # itself.
    # 2026-10-17: v0.15.1 adds frameIdle UAF, disconnect, and resume fixes.
    aquamarine = {
      url = "github:hyprwm/aquamarine/v0.15.1";
      inputs.nixpkgs.follows = "nixpkgs-hypr";
      inputs.hyprutils.follows = "hyprland/hyprutils";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.2";
      inputs.nixpkgs.follows = "nixpkgs-hypr";
      inputs.aquamarine.follows = "aquamarine";
    };

    # Hyprlock comes from the system nixpkgs (now 0.9.6). It must share the
    # system PAM/glibc ABI: the old standalone pin could not load PAM modules
    # after the system glibc update, causing authentication failures and crashes.

    # hyprdisplays: our Rust/iced display manager (source also in ~/git/hyprdisplays).
    # After pushing a change there: `nix flake update hyprdisplays`.
    hyprdisplays = {
      url = "github:blasphemetheus/hyprdisplays";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # per-monitor workspace sets (already in use). Third-party; follows hyprland.
    # TEMP PIN 2026-08-11: upstream shezdy/hyprsplit (last commit Jun 11) does
    # not compile against Hyprland 0.56 (helpers/Monitor.hpp → output/,
    # CCompositor → state/* refactor; issue #90). This is PR #89 ("chase
    # hyprland", cryeprecision's fork, author-tested on 0.56). Point back at
    # github:shezdy/hyprsplit once #89 or equivalent is merged.
    hyprsplit = {
      url = "github:cryeprecision/hyprsplit/6870872c24672745614d1cf61cb70dcc0d6fd0a9";
      inputs.hyprland.follows = "hyprland";
    };
    # (hyprspace input removed 2026-09-17: disabled since 2026-08-11 — upstream
    # KZDKM/Hyprspace doesn't compile against Hyprland 0.56 — yet still fetched
    # on every `nix flake update`. Re-add the input when upstream catches up.)
    # expo-style overview. hyprwm abandoned the original (removed from
    # hyprland-plugins in #663); this community fork is the maintained successor.
    # Pinned to release v0.56.2+3 (updated 2026-10-17; matches Hyprland 0.56.2;
    # sha pin because "+" in the tag name breaks flake ref parsing). Since the
    # fork now ships a working flake for 0.56, we consume its package directly —
    # pkgs/hyprexpo.nix (the hand-built 0.55.4 tag) is no longer referenced.
    hyprexpo = {
      url = "github:sandwichfarm/hyprexpo/852774edd577afad0c2e01d8b685772c80634524";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ags, ... }:
    let
      # One system per machine: hostModule is hosts/<name>/default.nix, which
      # imports the shared ./configuration.nix plus its own hardware scan.
      mkHost = hostModule: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Thread the flake inputs into configuration.nix so it can pull the
        # Hyprland compositor + plugin packages straight from the flakes above.
        specialArgs = { inherit inputs; };
        modules = [
          hostModule

          # Expose the v3 CLI as `ags-v3` WITHOUT replacing pkgs.ags: nixpkgs
          # consumers may still use the packaged AGS API independently.
          # (hyprsplit no longer overridden here — it now comes from the
          # cryeprecision/hyprsplit flake input, built against our pinned Hyprland.)
          {
            nixpkgs.overlays = [
              (_final: prev: {
                ags-v3 = ags.packages.${prev.stdenv.hostPlatform.system}.default;

                # (hyprexpo overlay removed 2026-09-17: the sandwichfarm fork's
                # flake ships a 0.56-compatible package, consumed directly in
                # configuration.nix. pkgs/hyprexpo.nix was the 0.55-era hand-build.)

                # hyprshade 5 supports Lua configuration natively; the old
                # 4.0.1 keyword-to-eval patch is no longer needed.

              })
            ];
          }

          home-manager.nixosModules.home-manager
          ({ config, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            # The account comes from the host's dotfiles.user block.
            home-manager.users.${config.dotfiles.user.name} = import ./home.nix;
          })
        ];
      };
    in
    {
      checks.x86_64-linux = import ./tests {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        inherit (self) nixosConfigurations;
      };

      nixosConfigurations = {
        # Canonical name (matches networking.hostName + the `nrs` alias).
        nixos_slanka = mkHost ./hosts/slanka;
        # Alias under the *runtime* hostname: the kernel drops the invalid
        # underscore, so `hostname` reports "nixosslanka". Hostname-derived tools
        # (nh os switch, with no explicit config) resolve this. Keep both in sync.
        nixosslanka = self.nixosConfigurations.nixos_slanka;

        # Laptop (Acer Aspire Go 15). Valid hostname, so one name is enough.
        aspire = mkHost ./hosts/aspire;
      };
    };
}
