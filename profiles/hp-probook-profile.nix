{ config, ... }:

{
 ### Import nix expression for hp-probook
 import = 
   [ ../configurations/hardware-configuration/hp-probook.nix      ### Hardware configuration file (Include the results of the hardware scan.)
     ../configurations/modules/app-opts/hp-probook.nix            ### Programs with options
     ../configurations/modules/networking/hp-probook.nix          ### Related to network
     ../configurations/modules/laptop/power-mgmt.nix              ### For laptop battery life
     ../configurations/modules/specific/desktop/gnome.nix         ### Related to GNOME DE
     ../configurations/modules/specific/desktop/x11.nix           ### Related to x11 Server (GUI server)
     ../configurations/modules/specific/vm/host/qemu-kvm-host.nix ### To add qemu/kvm as an desktop hypervisor
   ];
}
