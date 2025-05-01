{ lib, config, pkgs, pkgsExtra, zen-browser, ... }:

let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;
in
{
 home.packages =
   ### Packages common to all architectures
   (with pkgs; [
     vlc
     amberol
     bitwarden-desktop
     melonDS
     zen-browser.packages."${pkgs.system}".default
   ])
   ### Packages specific to x86_64-linux
   ++ lib.optionals isX86_64 (with pkgs; [
     discord
     spotify
     onlyoffice-desktopeditors
     prismlauncher
     rpi-imager
     gnome-extension-manager
     bottles
     melonDS
   ])
   ### Packages specific to aarch64-linux
   ++ lib.optionals isAarch64 (with pkgs; [
     legcord
   ])
   ### Packages from nixpkgs-23-11 for x86_64-linux only
   ++ lib.optionals isX86_64 (with pkgsExtra.pkgs-23-11; [
     citra
   ]);
}
