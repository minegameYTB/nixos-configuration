{ ... }:

{
  ### Import nix expression for vm-desktop
  imports = [
    ### Core
    ../../configurations/hardware-configuration/filesystem/btrfs
    ../../configurations/hardware-configuration/machines/vm/hardware-configuration.nix
    ../../configurations/configs/networking/desktop-config.nix
    ../../configurations/configs/system/tmp-on-tmpfs.nix

    ### X11 and desktop environment
    ../../configurations/configs/specific/desktop/environment/gnome.nix
    ../../configurations/configs/specific/desktop/sound.nix
    ../../configurations/configs/specific/desktop/autologin.nix
    #../../configurations/configs/specific/desktop/printer.nix
    ../../configurations/configs/specific/desktop/browser

    ### Services
    ../../configurations/configs/system/services/nix-channel-rm-dirs.nix

    ### Vm specific option
    ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix
    ../../configurations/configs/specific/vm/guest/openssh.nix

    ### Other
    ../../configurations/hardware-configuration/specific/swap.nix

    ### NixOS configuration module (distant flake)
    ### import default.nix from this directory ↓
    ../../configurations/config-modules
  ];
}
