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
     nix-search-cli
     efibootmgr
     ntfs3g
     nvd

     ### Pass $TERM env variable to ssh via a shell wrapper (and export openssh path as a global path for ssh wrapper)
     (pkgs.writeShellScriptBin "ssh" ''
       export PATH='${lib.getBin pkgs.openssh}'
       export TERM='xterm-256color'
       exec -a "$0" ${pkgs.openssh}/bin/ssh "$@"
     '')
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
       onlyoffice-desktopeditors

       ### Ghostty
       ghostty.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default
     ])
     ++
     (with pkgsExtra.pkgs-unstable; [
       ### Extra GUI packages from pkgsExtra (only if X11 is enabled)
       #bottles
     ])
 ));
}
