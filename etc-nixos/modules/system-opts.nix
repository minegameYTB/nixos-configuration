{ config, pkgs, ...  }:

{

  ### /tmp
  boot.tmp.cleanOnBoot = true;

 ### Plymouth
 boot.plymouth = {
   enable = true;
   theme = "bgrt";
 };

 ### Kernel
 boot.kernelParams = [
   "quiet"
   "splash"
   "boot.shell_on_fail"
 ];

 boot.kernel.sysctl = { "vm.swappiness" = 20; };

 ### Nix GC
 nix.settings.auto-optimise-store = true;

 nix.optimise = {
   automatic = true;
   dates = [ "weekly" ];
 };

 nix.gc = {
   automatic = true;
   dates = "weekly";
   options = "--delete-older-than 7d";
 };

 ### Nix Experimental
 nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
 ### Zram
 zramSwap.enable = true;

 ### Flatpak
 services.flatpak.enable = true;
 xdg.portal.enable = true;

 ### tlp
 services.power-profiles-daemon.enable = false;
 services.tlp = {
   enable = true;
   settings = {
     CPU_SCALING_GOVERNOR_ON_AC = "performance";
     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
 
    #Optional helps save long term battery health
     START_CHARGE_THRESH_BAT0 = 40; # 40 and bellow it starts to charge
     STOP_CHARGE_THRESH_BAT0 = 90; # 80 and above it stops charging

   };
 }; 
}
