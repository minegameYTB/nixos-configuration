{ callPackage, src, rev, branch, ... }:

{
  nixos-config = callPackage ./nixos-config/default.nix {
    inherit src rev branch;
  };
}
