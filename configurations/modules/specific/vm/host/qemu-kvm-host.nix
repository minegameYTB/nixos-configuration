{ config, pkgs, ... }:

{
 ### Virtualisation
 programs.virt-manager.enable = true;
 
 virtualisation = {
   kvmgt.enable = true;
   spiceUSBRedirection.enable = true;
   libvirtd = {
     enable = true;
     onShutdown = "shutdown";
     onBoot = "ignore";
     qemu.swtpm.enable = true;
   };
   libvirtd.qemu = {
     ovmf = {
       packages = [(pkgs.OVMF.override {
         secureBoot = true;
         tpmSupport = true;
       }).fd];
     };
     package = pkgs.qemu_kvm;
   };
 };
}
