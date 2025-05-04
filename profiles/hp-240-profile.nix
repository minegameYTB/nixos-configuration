{ ... }:

{
 ### Import nix expression for hp-240
 imports = [ 
   ../configurations/hardware-configuration/hp-240.nix                 ### Hardware configuration file (Include the results of the hardware scan.)
   ../configurations/configs/bootloader/grub2/efi.nix                  ### Grub 2 Bootloader
   ../configurations/configs/app-opts/hp-240.nix                       ### Programs with options
   ../configurations/configs/networking/desktop-config.nix             ### Related to network
   ../configurations/configs/system/tmp-on-disk.nix	                   ### Use /tmp on disk
   #../configurations/configs/specific/laptop/power-mgmt.nix           ### For laptop battery life
   ../configurations/configs/specific/desktop/gnome.nix                ### Related to Gnome shell
   #../configurations/configs/specific/vm/host/qemu-kvm-host.nix       ### To add qemu/kvm as an desktop hypervisor
   ../configurations/configs/specific/desktop/sound.nix                ### Sound server
   #../configurations/configs/specific/desktop/printer.nix             ### CUPS server
   #../configurations/configs/specific/desktop/autologin.nix           ### Permit autologin
   #../configurations/configs/specific/container/podman.nix            ### Enable podman and add toolbox as a system deps
   ../configurations/configs/system/services/nix-channel-rm-dirs.nix   ### Related to remove nix-channel folder (unused on my case)
   ../configurations/configs/system/services/flatpak.nix               ### Add flatpak support
   ../configurations/configs/stylix/stylix.nix                         ### Stylix conf
 ];
}
