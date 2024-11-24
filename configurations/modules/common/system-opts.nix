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
   	 auto-optimise-store = true;
   	 experimental-features = [ "nix-command" "flakes" ]; 
   };
   channel.enable = false;
   optimise = {
     automatic = true;
     dates = [ "weekly" ];
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

 ### nh tools
 programs.nh = {
  enable = true;
  flake = "/home/minegame/nixos-configuration/";
  clean = {
    enable = true;
    extraArgs = "--keep-since 7d --keep 3";
    dates = "weekly";
  };
 };
  
}
