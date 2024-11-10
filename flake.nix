### I used https://github.com/drupol/my-own-nixpkgs to create this monorepo
{
  description = "monorepo for testing things";

  inputs = {
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
}
