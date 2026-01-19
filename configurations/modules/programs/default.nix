{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Import all expression related to programs
  imports = [
    ./zen-browser-module.nix
    ./firefox-hardening.nix
  ];
}
