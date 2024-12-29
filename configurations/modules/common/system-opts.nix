{ lib, config, pkgs, ...  }:

{
 ### Boot config
 boot = {
   plymouth = {
     enable = true;
     theme = "bgrt";
   };
   initrd.systemd.enable = true;
   kernelParams = [
     "quiet"
     "boot.shell_on_fail"
   ];
   kernel.sysctl = { "vm.swappiness" = 20; };
   kernelPackages = pkgs.linuxPackages_latest;
 };
 
 ### Nix Settings
 nix = {
   channel.enable = false;
   registry.nix-custom-repo.to = {
     owner = "minegameYTB";
     repo = "nix-custom-repo";
     type = "github";
   };
   settings = {
     warn-dirty = false;
     auto-optimise-store = true;
     experimental-features = [ "nix-command" "flakes" ];
     trusted-users = [ "minegame" ]; 
   };
   gc = {
     automatic = true;
     dates = "weekly";
     options = "--delete-older-than 7d";
   };
   optimise = {
     automatic = true;
     dates = [ "weekly" ];
   };
 };
 
 ### Nvd diff hook
 system.activationScripts.report-changes = ''
   PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.nvd pkgs.nix ]}
   echo -e "\n===================================="
   echo      "| Running nvd diff to show changes |"
   echo -e   "====================================\n"
   nvd diff $(ls -dv /nix/var/nix/profiles/system-*-link|tail -2)
   echo ""
 '';

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
     "cat.ori" = "/run/booted-system/sw/bin/cat";
     "ls.ori" = "/run/booted-system/sw/bin/ls";
     ff = "fastfetch";
     nix = "nix -v";
     wget = "wget2";
     gc = "git commit";
     gadd = "git add";
     gpush = "git push";
     gpull = "git pull";
     nix-profile-upgrade = "nix profile upgrade --all";
   };
   interactiveShellInit = ''
      export NIXPKGS_COMMIT=$(jq -r '.nodes."nixpkgs".locked.rev' $HOME/nixos-configuration/flake.lock|cut -c1-8)
   '';
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
 
 ### Fwupd
 services.fwupd.enable = true;

 ### Apparmor
 security.apparmor.enable = true;
 
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
