{ ... }:

{
  ### Import nix expression for hp-240
  imports = [
    ### Core
    ### Include btrfs mountpoints expr
    ../configurations/hardware-configuration/filesystem/btrfs
    ../configurations/hardware-configuration/machines/hp-240/hardware-configuration.nix
    ../configurations/hardware-configuration/specific/intel-firmware.nix
    ../configurations/configs/bootloader/systemd-boot.nix
    ../configurations/configs/networking
    ../configurations/configs/system/tmp-on-tmpfs.nix
    #../configurations/configs/bootloader/grub2/grub2-efi.nix
    #../configurations/configs/specific/laptop/power-mgmt.nix

    ### X11 and desktop environment
    ../configurations/configs/specific/desktop/environment/gnome.nix
    ../configurations/configs/specific/desktop/sound.nix
    #../configurations/configs/specific/desktop/printer.nix
    ../configurations/configs/specific/desktop/autologin.nix
    ../configurations/configs/specific/desktop/browser

    ### Services
    ../configurations/configs/system/services/nix-channel-rm-dirs.nix

    ### Vm specific option
    #../configurations/configs/specific/vm/host/qemu-kvm-host.nix
    #../configurations/configs/specific/vm/guest/openssh.nix

    ### Games specific
    ../configurations/configs/specific/desktop/games/steam/steam-run-free.nix

    ### Other
    ../configurations/hardware-configuration/specific/swap.nix

    ### NixOS configuration module (distant flake)
    ### import default.nix from this directory ↓
    ../configurations/config-modules
  ];
}
