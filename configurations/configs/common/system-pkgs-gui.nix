{ config, pkgs, zen-browser, ... }:

{
 environment.systemPackages = with pkgs; [
     ### Utilities
     gparted
     gearlever   
     virt-viewer

     ### Other
     ghostty
     mission-center
     gnome-tweaks
   ];
}
