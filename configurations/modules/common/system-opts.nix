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

#boot.kernelPackages = pkgs.linuxPackages_xanmod_stable;
 
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
 
 ### Fish
 programs.fish = {
   enable = true;
   shellAliases = {
     ls = "lsd";
     cat = "bat";
     nix = "nix -v";
     gs = "git status";
     gc = "git commit";
     gadd = "git add";
     gpush = "git push";
     gpull = "git pull";
     ".." = "cd ..";
   };
  };

 ### Nix index
 programs.nix-index = {
   enable = true;
   enableFishIntegration = true;
 };
 
 programs.command-not-found.enable = false; 

}