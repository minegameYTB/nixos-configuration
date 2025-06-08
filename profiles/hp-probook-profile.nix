{ ... }:

{
 ### Import nix expression for hp-probook
 imports = [ 
   ### Core
   ### Include btrfs mountpoints expr
   ../configurations/hardware-configuration/filesystem/btrfs
   ../configurations/hardware-configuration/machines/hp-probook/hardware-configuration.nix
   ../configurations/hardware-configuration/specific/intel-firmware.nix
   ../configurations/configs/bootloader/systemd-boot.nix
   ../configurations/configs/networking/desktop-config.nix
   ../configurations/configs/system/tmp-on-disk.nix
   ../configurations/configs/specific/laptop/power-mgmt.nix

 
   ### X11 and desktop environment
   ../configurations/configs/specific/desktop/environment/gnome.nix
   #../configurations/configs/specific/desktop/plasma.nix
   ../configurations/configs/specific/desktop/sound.nix
   #../configurations/configs/specific/desktop/printer.nix

   ### Services
   ../configurations/configs/system/services/nix-channel-rm-dirs.nix

   ### Vm specific option
   ../configurations/configs/specific/vm/host/qemu-kvm-host.nix

   ### Games specific
   ../configurations/configs/specific/desktop/games

   ### Other
   #../configurations/configs/specific/container/podman.nix

   ### NixOS configuration module (distant flake)
   ### import default.nix from this directory ↓
   ../configurations/config-modules
 ];
}
