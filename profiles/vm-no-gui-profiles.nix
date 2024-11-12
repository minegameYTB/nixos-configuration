{ config, pkgs, ... }:

{
 ### Import nix expression for vm-no-gui
 imports = 
   [ ../configurations/hardware-configuration/vm-no-gui.nix         ### Hardware configuration file (Include the results of the hardware scan.)
     ../configurations/modules/app-opts/vm-no-gui.nix               ### Programs with options
     ../configurations/modules/networking/vm-no-gui.nix             ### Related to network
     ../configurations/modules/specific/vm/guest/qemu-kvm-guest.nix ### To use optimisation of qemu/kvm
   ];
}
