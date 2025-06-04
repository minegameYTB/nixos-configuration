{ ... }:

{
 ### Import nix expression for hp-240
 imports = [ 
   ### Core
   ### Include btrfs mountpoints expr
   ../configurations/hardware-configuration/filesystem/btrfs
   ../configurations/hardware-configuration/machines/hp-240/hardware-configuration.nix
   ../configurations/hardware-configuration/specific/intel-firmware.nix
   ../configurations/configs/bootloader/systemd-boot.nix
   ../configurations/configs/networking/desktop-config.nix
   ../configurations/configs/system/tmp-on-disk.nix
   #../configurations/configs/bootloader/grub2/grub2-efi.nix
   #../configurations/configs/specific/laptop/power-mgmt.nix
   
   ### X11 and desktop environment
   ../configurations/configs/specific/desktop/gnome.nix
   ../configurations/configs/specific/desktop/sound.nix
   #../configurations/configs/specific/desktop/printer.nix
   #../configurations/configs/specific/desktop/autologin.nix
   
   ### Services
   ../configurations/configs/system/services/nix-channel-rm-dirs.nix

   ### Vm specific option
   #../configurations/configs/specific/vm/host/qemu-kvm-host.nix
    ../configurations/configs/specific/vm/guest/openssh.nix

   ### Other
   ../configurations/configs/app-opts/hp-240.nix
   ../configurations/hardware-configuration/specific/swap.nix

   ### NixOS configuration module (distant flake)
   ### import default.nix from this directory ↓
   ../configurations/config-modules
 ];
}
