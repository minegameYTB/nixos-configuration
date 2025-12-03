{ ... }:

{
  ### Import expression for configuration modules (like configurations/config-modules in NixOS globale configuration)
  imports = [
    ./nix-index-db-hm
    ./declarative-flatpak
  ];
}
