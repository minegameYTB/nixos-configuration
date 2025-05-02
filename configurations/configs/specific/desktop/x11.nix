{ config, pkgs, ... }:

{
 ### Import plymouth expression
 imports = [ ./plymouth.nix ];
  
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

 ### Controller
 services.udev.extraRules = ''
   # USB
   ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
   ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
   
   # Bluetooth
   ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
   ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
 '';

# Enable touchpad support (enabled default in most desktopManager).
# services.xserver.libinput.enable = true;

}
