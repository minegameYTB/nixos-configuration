### (Flake created with https://librephoenix.com/2023-10-21-intro-flake-config-setup-for-new-nixos-users#org81dbd1d)

{
  description = "A flake with my configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # use the following for unstable:
    # nixpkgs.url = "nixpkgs/nixos-unstable";

    # or any branch you want:
    # nixpkgs.url = "nixpkgs/{BRANCH-NAME}";
  };

  outputs = { self, nixpkgs, ... }: 
  let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
  in {
    nixosConfigurations = {
      hp-probook = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./configurations/hp-probook-profile.nix
        ];
      };
    };
    nixosConfigurations = {
      hp-240 = lib.nixosSystem {
        system = system;
        modules = [
          ./configurations/configuration.nix
          ./configurations/hp-240-profile.nix
        ];
      };
    };
  };
}
