{ config, pkgs, ... }:

{
 ### Virt-manager
 programs.virt-manager.enable = true;

 ### Vm specific package
 environment.systemPackages = with pkgs; [ libguestfs ];

 ### KSM ram optimisation
 hardware.ksm.enable = true;

 ### Virtualisation settings
 virtualisation = {
   kvmgt.enable = true;
   spiceUSBRedirection.enable = true;
   libvirtd = {
     enable = true;
     shutdownTimeout = 90;
     onShutdown = "shutdown";
     onBoot = "ignore";
     qemu.swtpm.enable = true;
   };
   #libvirtd.qemu = {
   #  package = pkgs.qemu_kvm;
   #  ovmf.packages = [ pkgs.OVMFFull.fd ];
   #  ovmf.enable = true;
    #ovmf = {
      #packages = [(pkgs.OVMF.override {
      #  secureBoot = true;
      #  tpmSupport = true;
      #}).fd];
     #};
   #};
 };

 ### Nix specific
 virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = {
      memorySize = 1024; # Use 1024MiB memory.
      cores = 2;
      graphics = true; # Boot the vm in a window.
      diskSize = 15000; # Virtual machine disk size in MB.
    };
  };
}
