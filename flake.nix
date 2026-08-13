{
  description = "NixOS + Home Manager config for nixos_slanka";

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
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.2";
      inputs.nixpkgs.follows = "nixpkgs-hypr";
    };

    # hyprlock straight from upstream too: our nixpkgs pin ships 0.9.2, which
    # SEGVs on teardown (CShader dtor racing the async asset thread — the
    # 6-coredumps-in-2-days saga of 2026-07/08, see lock-wrapper.sh) and can
    # wedge in a busy-loop leaving the "oopsie" screen. v0.9.3 fixed the
    # use-after-free in async resource callbacks + NVIDIA teardown order;
    # v0.9.6 guards dtors against a destroyed EGL context. Deliberately NOT
    # following our nixpkgs (same cachix rationale as hyprland above).
    hyprlock.url = "github:hyprwm/hyprlock/v0.9.6";

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
    # workspace overview with window drag. Third-party; follows hyprland.
    hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };
    # expo-style overview. hyprwm abandoned the original (removed from
    # hyprland-plugins in #663); this community fork is the maintained successor.
    # Pinned to release v0.56.1+3 (2026-08-07, first 0.56-compatible release;
    # sha pin because "+" in the tag name breaks flake ref parsing). Since the
    # fork now ships a working flake for 0.56, we consume its package directly —
    # pkgs/hyprexpo.nix (the hand-built 0.55.4 tag) is no longer referenced.
    hyprexpo = {
      url = "github:sandwichfarm/hyprexpo/40352e2663deded7c6536b2fda1ed18a97234a80";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, astal, ags, ... }:
    let
      slanka = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Thread the flake inputs into configuration.nix so it can pull the
        # Hyprland compositor + plugin packages straight from the flakes above.
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix

          # Expose the v3 CLI as `ags-v3` WITHOUT replacing pkgs.ags: nixpkgs
          # consumers (hyprpanel calls `ags.bundle`) still need the v2 package.
          # (hyprsplit no longer overridden here — it now comes from the
          # shezdy/hyprsplit flake input, built against our pinned Hyprland.)
          {
            nixpkgs.overlays = [
              (final: prev: {
                ags-v3 = ags.packages.${prev.stdenv.hostPlatform.system}.default;

                # Replace nixpkgs' hyprlock 0.9.2 with the crash-fixed upstream
                # tag (see the hyprlock input comment). systemPackages picks
                # this up via `hyprlock` in configuration.nix.
                hyprlock = inputs.hyprlock.packages.${prev.stdenv.hostPlatform.system}.hyprlock;

                # hyprexpo has no flake at its last 0.55.x tag, so build it here
                # against the flake Hyprland (see pkgs/hyprexpo.nix).
                hyprexpo = final.callPackage ./pkgs/hyprexpo.nix {
                  hyprlandPkg = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland;
                };
              })
            ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.blewf = import ./home.nix;
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        # Canonical name (matches networking.hostName + the `nrs` alias).
        nixos_slanka = slanka;
        # Alias under the *runtime* hostname: the kernel drops the invalid
        # underscore, so `hostname` reports "nixosslanka". Hostname-derived tools
        # (nh os switch, with no explicit config) resolve this. Keep both in sync.
        nixosslanka = slanka;
      };
    };
}
