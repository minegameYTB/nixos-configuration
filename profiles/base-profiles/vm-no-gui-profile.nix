{ ... }:

{
 ### Import nix expression for vm-no-gui
 imports = [
   ### Core
   ../../configurations/hardware-configuration/filesystem/btrfs
   ../../configurations/hardware-configuration/machines/vm/hardware-configuration.nix
   ../../configurations/configs/networking/server-config.nix
   ../../configurations/configs/system/tmp-on-disk.nix
   
   ### Vm specific option
   ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix
   
   ### Services
   ../configurations/configs/system/services/nix-channel-rm-dirs.nix
   
   ### Server specific
   ../../configurations/configs/specific/vm/guest/openssh.nix
   
   ### Other
   ../../configurations/configs/app-opts/vm-no-gui.nix
   ../../configurations/hardware-configuration/specific/swap.nix
 ];
}
