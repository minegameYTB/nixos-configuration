{ config, pkgs, ...  }:

{
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

 boot.kernelPackages = pkgs.linuxPackages_latest;
 
 ### Nix Settings
 nix = {
   registry.nix-custom-repo.to = {
     owner = "minegameYTB";
     repo = "nix-custom-repo";
     type = "github";
   };
   settings = {
   	 warn-dirty = false;
   	 trusted-users = [ "root" "minegame" ];
   	 trusted-substituters = [ "https://hydra.nixos.org/" ];
   	 trusted-public-keys = [ "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs=" ];
   	 auto-optimise-store = true;
   	 experimental-features = [ "nix-command" "flakes" ]; 
   };
   channel.enable = false;
   optimise = {
     automatic = true;
     dates = [ "weekly" ];
   };
   gc = {
     automatic = true;
     dates = "weekly";
     options = "--delete-older-than 14d";
   };
 };
 
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
     wget = "wget2";
     gs = "git status";
     gc = "git commit";
     gadd = "git add";
     gpush = "git push";
     gpull = "git pull";
     nix-profile-upgrade = "nix flake update nix-custom-repo && nix profile upgrade '.*'";
   };
  };

 ### Nix index
 programs = {
   nix-index = {
     enable = true;
     enableFishIntegration = true;
   };
   command-not-found = {
     enable = false;
   };
 };
 

 ### Fstrim
 services.fstrim.enable = true;

 ### binfmt registration
 boot.binfmt.registrations.appimage = {
   wrapInterpreterInShell = false;
   interpreter = "${pkgs.appimage-run}/bin/appimage-run";
   recognitionType = "magic";
   offset = 0;
   mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
   magicOrExtension = ''\x7fELF....AI\x02'';
 };
 
}
