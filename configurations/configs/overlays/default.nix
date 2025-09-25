{ lib, pkgs, ... }:

{
 ### Import package overlays (and patch) on global software
 nixpkgs.overlays = [
   #(import ../overlays/coreutils-full.nix)
   #(import ../overlays/appimage-run.nix)
   #(import ../overlays/gnome-control-center.nix)
   #(import ../overlays/gnome-mutter.nix)
   #(import ../overlays/package-name.nix)
 ];
}
