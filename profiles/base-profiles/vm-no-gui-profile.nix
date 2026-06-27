{ ... }:

{
  ### Import nix expression for vm-no-gui
  imports = [
    ### Core
    ../../configurations/hardware-configuration/machines/vm/hardware-configuration.nix
    ../../configurations/hardware-configuration/specific/intel-firmware.nix
    ../../configurations/configs/networking
    ../../configurations/configs/system/tmp-on-tmpfs.nix
    ../../configurations/configs/specific/desktop/x11.nix # for kmscon config

    ### Vm specific option
    ../../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix

    ### Services
    #../../configurations/configs/system/services/nix-channel-rm-dirs.nix

    ### Server specific
    ../../configurations/configs/specific/vm/guest/openssh.nix
    #../../configurations/configs/specific/vm/guest/tailscale.nix

    ### Other
    ../../configurations/hardware-configuration/specific/swap.nix
  ];
}
