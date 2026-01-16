{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Boot config
  boot = {
    binfmt = {
      preferStaticEmulators = true;
      emulatedSystems = [
        "aarch64-linux"
      ];
    };
    initrd.systemd = {
      enable = true;
      emergencyAccess = "$y$j9T$CmuNpg/fSyEMO8pehMLwU.$Oe7w2sKzs6teBwP5rU.OOVeGyMAHKL8Pz3JunPlLOv/";
    };
    kernelParams = [
      "quiet"
      "boot.shell_on_fail"
    ];
    kernel.sysctl = {
      "kernel.panic" = 10;
      "vm.swappiness" = 10;
      "kernel.printk" = "3 3 3 3";

      # Hardening
      "kernel.kptr_restrict" = 2;
      "kernel.kexec_load_disabled" = 1;
    };
    kernelPackages = pkgs.linuxKernel.packages.linux_6_18;
  };
}
