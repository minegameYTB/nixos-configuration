{ ... }:

{
 ### Import nix expression for vm-desktop
 imports = [ 
   ../../configurations/hardware-configuration/vm/hardware-configuration.nix                    ### Hardware configuration file (Include the results of the hardware scan.)
   ../../configurations/configs/app-opts/vm-desktop.nix                  ### Programs with options
   ../../configurations/configs/networking/desktop-config.nix             ### Related to network
   ../../configurations/configs/system/tmp-on-disk.nix                   ### Use /tmp on disk
   ../../configurations/configs/specific/desktop/gnome.nix               ### Related to GNOME DE
   ../../configurations/configs/specific/desktop/x11.nix                 ### Related to x11 Server (GUI server)
   ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix     ### To use optimisation of qemu/kvm
   ../../configurations/configs/specific/desktop/sound.nix               ### Sound server
   #../../configurations/configs/specific/desktop/autologin.nix          ### Permit autologin
   ../../configurations/configs/system/services/nix-channel-rm-dirs.nix  ### Related to remove nix-channel folder (unused on my case)
   ../../configurations/configs/stylix/stylix.nix                        ### Stylix conf
 ];
}
