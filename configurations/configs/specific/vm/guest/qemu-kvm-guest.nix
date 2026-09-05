{ config, pkgs, ... }:

{
  ### qemu-guest-agent
  services.qemuGuest.enable = true;

  ### spice-vd-agent
  services.spice-vdagentd.enable = true;

  ### Nix specific
  ### Base sizing (memorySize/cores/diskSize) is defined globally in
  ### configurations/configs/common/system-opts/vm-variant.nix —
  ### only VM-window specifics remain here.
  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = {
      graphics = true; # Boot the vm in a window.

      # virgl GPU acceleration (requires OpenGL host session, e.g. X11/Wayland)
      qemu.options = [
        "-device virtio-vga-gl"
        "-display gtk,gl=on"
      ];
    };
  };

  ### Temporary fix https://github.com/NixOS/nixpkgs/issues/481078
  systemd = {
    services.ModemManager.enable = false;

    # Ensure that the spice vdagent is running.
    # https://github.com/NixOS/nixpkgs/issues/481078
    # https://github.com/NixOS/nixpkgs/pull/266080
    user.services.spice-vdagent = {
      description = "spice-vdagent user daemon";
      after = [
        "spice-vdagentd.service"
        "graphical-session.target"
      ];
      requires = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig.ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
      unitConfig.ConditionPathExists = "/run/spice-vdagentd/spice-vdagent-sock";
    };
  };
}
