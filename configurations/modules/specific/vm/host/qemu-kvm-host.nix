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

}
