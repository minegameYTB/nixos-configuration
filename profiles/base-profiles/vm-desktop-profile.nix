{ ... }:

{
 ### Import nix expression for vm-desktop
 imports = [
   ### Core
   ../../configurations/hardware-configuration/vm/hardware-configuration.nix
   ../../configurations/configs/app-opts/vm-desktop.nix
   ../../configurations/configs/networking/desktop-config.nix
   ../../configurations/configs/system/tmp-on-disk.nix
   
   ### X11 and desktop environment
   ../../configurations/configs/specific/desktop/gnome.nix
   ../../configurations/configs/specific/desktop/sound.nix
   #../../configurations/configs/specific/desktop/autologin.nix
   #../../configurations/configs/specific/desktop/printer.nix
   
   ### Services
   ../../configurations/configs/system/services/nix-channel-rm-dirs.nix
   
   ### Vm specific option
   ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix
   
   ### Other
   ../../configurations/configs/app-opts/vm-desktop.nix
   
   ### NixOS configuration module (distant flake)
   ### import default.nix from this directory ↓
   ../../configurations/config-modules
 ];
}
