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
    hyprland.url = "github:hyprwm/Hyprland/v0.55.4";

    # hyprlock straight from upstream too: our nixpkgs pin ships 0.9.2, which
    # SEGVs on teardown (CShader dtor racing the async asset thread — the
    # 6-coredumps-in-2-days saga of 2026-07/08, see lock-wrapper.sh) and can
    # wedge in a busy-loop leaving the "oopsie" screen. v0.9.3 fixed the
    # use-after-free in async resource callbacks + NVIDIA teardown order;
    # v0.9.6 guards dtors against a destroyed EGL context. Deliberately NOT
    # following our nixpkgs (same cachix rationale as hyprland above).
    hyprlock.url = "github:hyprwm/hyprlock/v0.9.6";

    # per-monitor workspace sets (already in use). Third-party; follows hyprland.
    hyprsplit = {
      url = "github:shezdy/hyprsplit";
      inputs.hyprland.follows = "hyprland";
    };
    # workspace overview with window drag. Third-party; follows hyprland.
    hyprspace = {
      url = "github:KZDKM/Hyprspace";
      inputs.hyprland.follows = "hyprland";
    };
    # expo-style overview. hyprwm abandoned the original (removed from
    # hyprland-plugins in #663); this community fork is the maintained successor.
    hyprexpo = {
      url = "github:sandwichfarm/hyprexpo";
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
