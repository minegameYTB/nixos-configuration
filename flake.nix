### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, lanzaboote, ... }: 
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        inherit system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-probook-profile.nix
          lanzaboote.nixosModules.lanzaboote
          ({ pkgs, lib, ... }: {
            environment.systemPackages = with pkgs; [
              sbctl
            ];

            boot = {
              loader.systemd-boot.enable = lib.mkForce false;
              lanzaboote = {
                enable = true;
                pkiBundle = "/etc/secureboot";
              };
            };
          })
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
