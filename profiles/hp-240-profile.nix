{ config, pkgs, ... }:

{
 ### Import nix expression for hp-240
 imports = 
   [ ../configurations/hardware-configuration/hp-240.nix          ### Hardware configuration file (Include the results of the hardware scan.)
     ../configurations/modules/bootloader/grub2.nix               ### Grub 2 Bootloader
     ../configurations/modules/app-opts/hp-240.nix                ### Programs with options
     ../configurations/modules/networking/hp-240.nix              ### Related to network
     ../configurations/modules/system/tmp-on-disk.nix		  ### Use /tmp on disk
     ../configurations/modules/specific/games/steam-run-only.nix  ### Only use steam-run
    #../configurations/modules/specific/laptop/power-mgmt.nix     ### For laptop battery life
     ../configurations/modules/specific/desktop/gnome.nix         ### Related to GNOME DE
     ../configurations/modules/specific/desktop/x11.nix           ### Related to x11 Server (GUI server)
    #../configurations/modules/specific/vm/host/qemu-kvm-host.nix ### To add qemu/kvm as an desktop hypervisor
     ../configurations/modules/specific/desktop/sound.nix         ### Sound server
    #../configurations/modules/specific/desktop/printer.nix       ### CUPS server
     ../configurations/modules/specific/desktop/autologin.nix     ### Permit autologin
     ../configurations/modules/specific/container/podman.nix      ### Enable podman and add toolbox as a system deps
   ];
}
