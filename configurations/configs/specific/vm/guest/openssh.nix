{
  config,
  ...
}:

{
  ### enable openssh for this type of machine
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  ### /boot must exist: a missing ReadWritePaths entry fails the sandbox
  ### setup. mkdir -p only (a tmpfiles rule with a mode would chmod the
  ### vfat ESP and fight efi-mountpoint.nix's fmask/dmask=0077). Covers
  ### BIOS/GRUB without ESP and `build-vm` guests (no bootloader, no /boot).
  system.activationScripts.mkBootDir = "mkdir -p /boot";

  ### SSH hardening. No RequiresMountsFor on /boot on purpose: sshd must
  ### stay reachable when /boot is missing or unmounted. ReadWritePaths
  ### keeps sudo / nixos-rebuild / bootloader updates / activation / sftp
  ### working under ProtectSystem=strict.
  systemd.services.sshd = {
    serviceConfig = {
      ProtectSystem = "strict";

      ReadWritePaths = [
        "/run" # sudo timestamps, dbus/systemd sockets
        "/nix" # nixos-rebuild profile activation
        "/boot" # bootloader update (systemd-boot)
        "/etc" # activation writes /etc/NIXOS + symlinks
        "/home" # user workdirs, sftp
      ];

      PrivateTmp = true;

      ### cgroup v2 caps (% of RAM: scale with each machine)
      MemoryAccounting = true;
      MemoryHigh = "50%"; # soft: pressure to reclaim above this
      MemoryMax = "75%"; # hard: OOM-kill above this
      TasksMax = 256; # max number of tasks/threads
    };
  };
}
