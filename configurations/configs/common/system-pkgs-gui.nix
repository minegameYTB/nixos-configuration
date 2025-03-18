{ config, pkgs, zen-browser, ... }:

{
 environment.systemPackages = with pkgs; [
     ### Zen browser flake (import as a inputs (and as zen-browser))
     #inputs.zen-browser.packages."${system}".default
     zen-browser.packages."${system}".default

     ### Utilities
     gparted
     gearlever   
     virt-viewer
     pika-backup

     ### Other
     ghostty
     mission-center
     gnome-tweaks
   ];
}
