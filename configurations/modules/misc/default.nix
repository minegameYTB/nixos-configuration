{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./marker.nix
    ./flake-copy.nix
    ./primary-user.nix
    ./auto-update
  ];
}
