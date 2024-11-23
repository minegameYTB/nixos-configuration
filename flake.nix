### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
   #nix-custom-repo.url = "github:minegameYTB/nix-custom-repo";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # use the following for unstable:
    # nixpkgs.url = "nixpkgs/nixos-unstable";

    # or any branch you want:
    # nixpkgs.url = "nixpkgs/{BRANCH-NAME}";
  };

  outputs = inputs@{ self, nixpkgs, home-manager,  ... }: 
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
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
            home-manager.users.minegame = import ./home-manager/home.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };
      hp-240 = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/hp-240-profile.nix
           home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./home-manager/home.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };
      vm-desktop = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-desktop-profile.nix
           home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.minegame = import ./home-manager/home.nix;
            home-manager.backupFileExtension = "bak";
          }
        ];
      };
      vm-no-gui = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./profiles/vm-no-gui-profile.nix
           home-manager.nixosModules.home-manager
          {
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
