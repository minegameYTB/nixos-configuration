{
  config,
  pkgs,
  lib,
  ...
}:

{
  ### Enable path registry patching
  nixpkgs.flake.setFlakeRegistry = false;
  nixpkgs.flake.setNixPath = false;

  ### Override nixpkgs regsitry to use current pkgs path (patched and vanilla nixpkgs)
  nix.registry.nixpkgs = lib.mkDefault {
    from = {
      id = "nixpkgs";
      type = "indirect";
    };
    to = {
      type = "path";
      path = pkgs.path;
    };
  };

  ### Define <nixpkgs> for nix-path
  nix.settings.nix-path = lib.mkForce [
    "nixpkgs=${pkgs.path}"
  ];
}
