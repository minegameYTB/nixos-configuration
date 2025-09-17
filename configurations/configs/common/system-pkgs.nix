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
 environment.systemPackages = (with pkgs; [
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
     exec -a "$0" ${config.programs.ssh.package}/bin/ssh "$@"
   '')
   #nixos-rebuild
 ]) ++ (with pkgsExtra.pkgs-unstable; [
   ### Extra packages always installed (from pkgsExtra)
   #ventoy
 ]) ++ (lib.optionals config.services.xserver.enable (
   (with pkgs; [
     ### GUI Packages (only if X11 is enabled)
     gparted
     gearlever
     onlyoffice-desktopeditors
     github-desktop
     spotify

     ### Ghostty
     ghostty.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default
   ]) ++ (with pkgsExtra.pkgs-unstable; [
     ### Extra GUI packages from pkgsExtra (only if X11 is enabled)
     deezer-enhanced
     #bottles
   ])
 ));
}
