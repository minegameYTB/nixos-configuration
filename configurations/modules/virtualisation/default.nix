{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./vmware-ws-iso.nix
    ./nspawnctl.nix
  ];
}
