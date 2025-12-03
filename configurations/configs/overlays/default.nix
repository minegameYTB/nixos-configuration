{ lib, pkgs, ... }:

{
  ### Import package overlays (and patch) on global software
  nixpkgs.overlays = [
    #(import ./coreutils-full.nix)
    #(import ./uutils-coreutils.nix)
    #(import ./appimage-run.nix)
    #(import ./gnome-control-center.nix)
    #(import ./gnome-mutter.nix)
    #(import ./package-name.nix)
  ];
}
