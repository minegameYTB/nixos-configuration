{ ... }:

{
 ### Import nix expression for vm-no-gui
 imports = [
   ### Core
   ../../configurations/hardware-configuration/vm/hardware-configuration.nix
   ../../configurations/configs/networking/server-config.nix
   ../../configurations/configs/system/tmp-on-disk.nix
   
   ### Vm specific option
   ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix
   
   ### Server specific
   ../../configurations/configs/specific/vm/guest/openssh.nix
   
   ### Other
   ../../configurations/configs/app-opts/vm-no-gui.nix
 ];
}
