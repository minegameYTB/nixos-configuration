{ ... }:

{
 ### Import nix expression for vm-no-gui
 imports = [ 
   ../../configurations/hardware-configuration/vm.nix                ### Hardware configuration file (Include the results of the hardware scan.)
   ../../configurations/configs/app-opts/vm-no-gui.nix               ### Programs with options
   ../../configurations/configs/networking/server-config.nix         ### Related to network
   ../../configurations/configs/system/tmp-on-disk.nix               ### Use /tmp on disk
   ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix ### To use optimisation of qemu/kvm
   ../../configurations/configs/specific/vm/guest/openssh.nix        ### Enable openssh service
 ];
}
