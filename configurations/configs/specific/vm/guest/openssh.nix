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

  ### /boot must exist for the ReadWritePaths entry below: a missing path
  ### fails the sshd sandbox setup ("No such file or directory"). Machines
  ### without a separate /boot filesystem (BIOS/GRUB) and `build-vm` guests
  ### have no /boot mount creating the directory, so create it here.
  ### mkdir -p only creates when missing and never alters the permissions
  ### of an already-mounted ESP (a tmpfiles `d` rule with a mode would
  ### chmod the vfat mountpoint and fight efi-mountpoint.nix's
  ### fmask/dmask=0077).
  system.activationScripts.mkBootDir = "mkdir -p /boot";

  ### SSH service hardening
  ### NOTE: no RequiresMountsFor on /boot here on purpose. sshd must stay
  ### reachable even when /boot is missing or unmounted — failed ESP mount
  ### on a physical machine, BIOS/GRUB without a separate /boot, or
  ### `nixos-rebuild build-vm` guests which boot directly (no bootloader,
  ### no /boot mount at all): requiring boot.mount made sshd fail whenever
  ### /boot was absent. Bootloader updates over SSH still work via the
  ### /boot entry in ReadWritePaths below.
  systemd.services.sshd = {
    serviceConfig = {
      ProtectSystem = "strict";

      ### Keep sudo / nixos-rebuild usable over SSH: re-open only the
      ### paths needed for ops (strict makes the whole fs read-only)
      ReadWritePaths = [
        "/run" # sudo timestamps, dbus/systemd sockets
        "/nix" # nixos-rebuild profile activation
        "/boot" # bootloader update (systemd-boot)
        "/etc" # activation writes /etc/NIXOS + symlinks
        "/home" # user workdirs
      ];

      PrivateTmp = true;

      ### Experimental cgroup v2 resource limits (percentage of RAM:
      ### adapts automatically to each machine's total memory)
      MemoryAccounting = true;
      MemoryHigh = "50%"; # soft: pressure to reclaim above this
      MemoryMax = "75%"; # hard: OOM-kill above this
      TasksMax = 256; # max number of tasks/threads
    };
  };
}
