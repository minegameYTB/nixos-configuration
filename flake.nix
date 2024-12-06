### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/b681065d0919f7eb5309a93cea2cfa84dec9aa88"; ### Commit related to nixos-24.11 branch
    home-manager = {
      url = "github:nix-community/home-manager/62d536255879be574ebfe9b87c4ac194febf47c5"; ### Commit related to home-manager/release-24.11 branch
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }: 
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        inherit system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-probook-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./home-manager/home.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };
      hp-240 = lib.nixosSystem {
        inherit system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-240-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./home-manager/home.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };
      vm-desktop = lib.nixosSystem {
        inherit system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-profile.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./home-manager/home.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };
    };
  };
}
