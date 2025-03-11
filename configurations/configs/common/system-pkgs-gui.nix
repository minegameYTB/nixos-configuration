{ config, pkgs, zen-browser, ... }:

{
 environment.systemPackages = with pkgs; [
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
