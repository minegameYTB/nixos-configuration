{ callPackage, ... }:

{
  nixos-config = callPackage ./config/nixos-config.nix { };
}
