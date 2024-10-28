{
  description = "A flake with my configuration (and soon a pkgs repository)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";

    # use the following for unstable:
    # nixpkgs.url = "nixpkgs/nixos-unstable";

    # or any branch you want:
    # nixpkgs.url = "nixpkgs/{BRANCH-NAME}";
  };

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        desktop = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configurations/configuration.nix ];
      };
    };
  };
}
