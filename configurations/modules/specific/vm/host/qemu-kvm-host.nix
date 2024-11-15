{ config, pkgs, ... }:

{
 ### Virtualisation
 programs.virt-manager.enable = true;
 
 virtualisation = {
   spiceUSBRedirection.enable = true;
   libvirtd = {
     enable = true;
     onShutdown = "shutdown";
     qemu.swtpm.enable = true;
   };
 };

 ### OVMF package
 virtualisation.libvirtd.qemu.ovmf.packages = [ pkgs.OVMFFull.fd ];
}
