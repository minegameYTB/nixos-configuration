{ config, pkgs, pkgsExtra, ... }:

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
 
 ### Mesa
 hardware.graphics = {
   ### Fix mesa version on nixpkgs 25.05
   enable = true;
   package = pkgsExtra.pkgs-25-05.mesa;
   
   ### Enable 32-bit platform
   enable32Bit = true;
   package32 = pkgsExtra.pkgs-25-05.pkgsi686Linux.mesa;
 };
 ### Exclude Xterm 
 services.xserver.excludePackages = with pkgs; [
   xterm
 ];

 ### Localsend
 programs.localsend.enable = true;

 ### Controller
 services.udev.extraRules = ''
   # USB
   ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
   ATTRS{name}=="Sony Interactive Entertainment DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
   
   # Bluetooth
   ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
   ATTRS{name}=="DualSense Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
 '';

 ### IBUS
 i18n.inputMethod = {
   enable = true;
   type = "ibus";
   ibus.engines = with pkgs.ibus-engines; [ anthy hangul mozc libpinyin ];
 };

# Enable touchpad support (enabled default in most desktopManager).
# services.xserver.libinput.enable = true;

}
