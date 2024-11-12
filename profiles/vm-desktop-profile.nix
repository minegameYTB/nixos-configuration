{ config, pkgs, ... }:

{
 ### Import nix expression for vm-desktop
 imports = 
   [ ../configurations/hardware-configuration/vm-desktop.nix        ### Hardware configuration file (Include the results of the hardware scan.)
     ../configurations/modules/app-opts/vm-desktop.nix              ### Programs with options
     ../configurations/modules/networking/vm-desktop.nix            ### Related to network
     ../configurations/modules/specific/desktop/gnome.nix           ### Related to GNOME DE
     ../configurations/modules/specific/desktop/x11.nix             ### Related to x11 Server (GUI server)
     ../configurations/modules/specific/vm/guest/qemu-kvm-guest.nix ### To use optimisation of qemu/kvm
     ../configurations/modules/specific/desktop/sound.nix           ### Sound server
     ../configurations/modules/specific/desktop/autologin.nix       ### Permit autologin
   ];
}
