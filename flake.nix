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
  };

  outputs = { nixpkgs, home-manager, astal, ags, ... }:
    let
      slanka = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix

          # Expose the v3 CLI as `ags-v3` WITHOUT replacing pkgs.ags: nixpkgs
          # consumers (hyprpanel calls `ags.bundle`) still need the v2 package.
          {
            nixpkgs.overlays = [
              (final: prev: {
                ags-v3 = ags.packages.${prev.stdenv.hostPlatform.system}.default;
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
