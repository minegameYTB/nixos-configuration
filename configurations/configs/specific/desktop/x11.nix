{ config, pkgs, ... }:

{
 ### Import plymouth expression
 #imports = [ ./plymouth.nix ];
  
 # Enable the X11 windowing system.
 services.xserver.enable = true;

 # Configure keymap in X11
 services.xserver.xkb = {
   layout = "fr";
   variant = "";
 };
 
 ### Exclude Xterm 
 services.xserver.excludePackages = with pkgs; [
   xterm
 ];
 
# Enable touchpad support (enabled default in most desktopManager).
# services.xserver.libinput.enable = true;

}
