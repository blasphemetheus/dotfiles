{
  description = "NixOS + Home Manager config for nixos_slanka";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      slanka = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix

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
