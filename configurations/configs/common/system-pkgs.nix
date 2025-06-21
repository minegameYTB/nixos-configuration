{ lib, inputs, config, pkgs, pkgsExtra, ghostty, ... }:

let
  ### Add external packages
  #fhsEnv-dev = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
  
  ### Wrapper script
  #nixos-rebuild = pkgs.writeShellScriptBin "nixos-rebuild" ''
  #  exec -a "$0" ${pkgs.nixos-rebuild}/bin/nixos-rebuild -L "$@"
  #'';
in
{
 nixpkgs.overlays = [
   #(import ../overlays/coreutils-full.nix)
   #(import ../overlays/appimage-run.nix)
   #(import ../overlays/gnome-control-center.nix)
   #(import ../overlays/package-name.nix)
 ];

 environment.systemPackages = 
   (with pkgs; [
     ### CLI
     wget
     jq
     nix-search-cli
     efibootmgr
     ntfs3g
     git
     ripgrep
     nvd
     #nixos-rebuild
   ])
   ++
   (with pkgsExtra.pkgs-unstable; [
     ### Extra packages always installed (from pkgsExtra)
     #ventoy
   ])
   ++
   (lib.optionals config.services.xserver.enable (
     (with pkgs; [
       ### GUI Packages (only if X11 is enabled)
       gparted
       gearlever
       ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
     ])
     ++
     (with pkgsExtra.pkgs-unstable; [
       ### Extra GUI packages from pkgsExtra (only if X11 is enabled)
       #bottles
     ])
 ));
}
