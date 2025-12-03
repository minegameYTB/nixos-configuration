{
  lib,
  config,
  pkgs,
  pkgsExtra,
  ...
}:

{
  ### Import all expression related to programs
  imports = [
    ./zen-browser-module.nix
    ./firefox-hardening.nix
  ];
}
