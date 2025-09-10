{ lib, config, pkgs, ... }:

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
     "vm.swappiness" = 20;
   };
   #kernelPackages = pkgs.linuxKernel.packages.linux_6_12;
 };

 ### Rsyslog
 services.rsyslogd.enable = true;
}
