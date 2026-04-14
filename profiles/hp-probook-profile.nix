{ ... }:

{
  ### Import nix expression for hp-probook
  imports = [
    ### Core
    ../configurations/hardware-configuration/machines/hp-probook/hardware-configuration.nix
    ../configurations/hardware-configuration/specific/intel-firmware.nix
    ../configurations/configs/bootloader/systemd-boot.nix
    ../configurations/configs/networking
    ../configurations/configs/system/tmp-on-tmpfs.nix
    ../configurations/configs/specific/laptop/power-mgmt.nix

    ### X11 and desktop environment
    ../configurations/configs/specific/desktop/environment/gnome.nix
    ../configurations/configs/specific/desktop/sound.nix
    #../configurations/configs/specific/desktop/printer.nix
    ../configurations/configs/specific/desktop/browser

    ### Services
    ../configurations/configs/system/services/nix-channel-rm-dirs.nix

    ### Vm specific option
    ../configurations/configs/specific/vm/host/qemu-kvm-host.nix

    ### Games specific
    ../configurations/configs/specific/desktop/games

    ### Other
    ../configurations/configs/specific/container/podman.nix
    ../configurations/hardware-configuration/specific/swap.nix

    ### NixOS configuration module (distant flake)
    ### import default.nix from this directory ↓
    ../configurations/config-modules

    ### Add lanzaboote (separate module)
    #../configurations/config-modules/lanzaboote
  ];
}
