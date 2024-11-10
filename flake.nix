### I used https://github.com/drupol/my-own-nixpkgs to create this monorepo
{
  description = "monorepo for testing things";

  inputs = {
<<<<<<< HEAD
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, systems, ... }:
    let
      pkgs = import nixpkgs {};
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.pkgs-by-name-for-flake-parts.flakeModule
        ./imports/overlay.nix
        ./imports/formatter.nix
        ./imports/pkgs-all.nix
      ];
    
      nixosModules = {
        "nix-monorepo" = { config, pkgs, ... }: {
           option = {};
           config = {};
         };
      };
    };
=======
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # use the following for unstable:
    # nixpkgs.url = "nixpkgs/nixos-unstable";

    # or any branch you want:
    # nixpkgs.url = "nixpkgs/{BRANCH-NAME}";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }: 
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-probook-profile.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./configurations/home-manager/home.nix;
          }
        ];
      };
    };
    nixosConfigurations = {
      hp-240 = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-240-profile.nix
           home-manager.nixosModules.home-manager
           {
             home-manager.useGlobalPkgs = true;
             home-manager.useUserPackages = true;
             home-manager.users.minegame = import ./configurations/home-manager/home.nix;
           }
        ];
      };
    };
  };
>>>>>>> parent of e44915f (flake.nix: Add custom monorepo from github)
}
