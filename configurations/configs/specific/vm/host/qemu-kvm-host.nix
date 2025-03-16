{ config, pkgs, ... }:

{
 ### Virt-manager
 programs.virt-manager.enable = true;

 ### KSM ram optimisation
 hardware.ksm.enable = true;

 ### Virtualisation settings
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
     package = pkgs.qemu_kvm;
     ovmf.packages = [ pkgs.OVMFFull.fd ];
     ovmf.enable = true;
    #ovmf = {
      #packages = [(pkgs.OVMF.override {
      #  secureBoot = true;
      #  tpmSupport = true;
      #}).fd];
     #};
   };
 };
}
