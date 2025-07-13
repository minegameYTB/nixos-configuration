{ lib, config, pkgs, pkgsExtra, zen-browser, ... }:

let
  isX86_64 = pkgs.stdenvNoCC.hostPlatform.isx86_64;
  isAarch64 = pkgs.stdenvNoCC.hostPlatform.isAarch64;
in
{
 home.packages =
   ### All arch
   (with pkgs; [
     vlc
     amberol
     pika-backup
     melonDS
     github-desktop

     ### Libreoffice (and langpack)
     #libreoffice-fresh
     hunspellDicts.fr-any
   ])
   ### All arch (pkgs from unstable branch)
   ++ (with pkgsExtra.pkgs-unstable; [
     bitwarden-desktop
     #melonDS
   ])
   ### Packages from pkgs-24.11 (all arch)
   ++ (with pkgsExtra.pkgs-24-11; [
     rpi-imager
   ])
   ### Packages specific to x86_64-linux (main pkgs branch)
   ++ lib.optionals isX86_64 (with pkgs; [
     discord
     spotify
     onlyoffice-desktopeditors
     prismlauncher
   ])
   ### Packages specific to aarch64-linux (main pkgs branch)
   ++ lib.optionals isAarch64 (with pkgs; [
     legcord
   ])
   ### Packages from nixpkgs-23-11 for x86_64-linux only
   ++ lib.optionals isX86_64 (with pkgsExtra.pkgs-23-11; [
     citra
   ])
   ### Packages from pkgs-unstable for x86_64-linux only
   ++ lib.optionals isX86_64 (with pkgsExtra.pkgs-unstable; [
     ### unstable pkgs here
   ])
   ++ lib.optionals isX86_64 (with pkgsExtra.pkgs-pr; [
     ### Temporairy add deezer-enhanced here
     deezer-enhanced
   ])
   ### Packages from pkgs-unstable for aarch64-linux 
   ++ lib.optionals isAarch64 (with pkgsExtra.pkgs-unstable; [
     ### unstable pkgs here
   ]);
}
