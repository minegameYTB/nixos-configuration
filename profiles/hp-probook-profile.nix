{ ... }:

{
 ### Import nix expression for hp-probook
 imports = [ 
   ../configurations/hardware-configuration/hp-probook.nix            ### Hardware configuration file (Include the results of the hardware scan.)
   ../configurations/configs/bootloader/systemd-boot.nix              ### Systemd-boot Bootloader
   ../configurations/configs/app-opts/hp-probook.nix                  ### Programs with options
   ../configurations/configs/networking/hp-probook.nix                ### Related to network
   ../configurations/configs/system/tmp-on-disk.nix                   ### Use /tmp on disk
   ../configurations/configs/specific/laptop/power-mgmt.nix           ### For laptop battery life
   ../configurations/configs/specific/desktop/gnome.nix               ### Related to Gnome DE
   #../configurations/configs/specific/desktop/plasma.nix             ### Related to Kde plasma DE
   ../configurations/configs/specific/vm/host/qemu-kvm-host.nix       ### To add qemu/kvm as an desktop hypervisor
   ../configurations/configs/specific/desktop/sound.nix               ### Sound server
   #../configurations/configs/specific/desktop/printer.nix            ### CUPS server
   #../configurations/configs/specific/container/podman.nix           ### Enable podman and add distrobox as a system deps
   ../configurations/configs/system/services/nix-channel-rm-dirs.nix  ### Related to remove nix-channel folder (unused on my case)
   ../configurations/configs/system/services/flatpak.nix              ### Add flatpak support
   ../configurations/configs/stylix/stylix.nix                         ### Stylix conf
 ];
}
