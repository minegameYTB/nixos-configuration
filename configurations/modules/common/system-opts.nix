{ lib, config, pkgs, ...  }:

{
 ### Boot config
 boot = {
   plymouth = {
     enable = true;
     theme = "bgrt";
   };
   binfmt = {
    preferStaticEmulators = true;
     emulatedSystems = [
       "aarch64-linux"
     ];
   };
   initrd.systemd.enable = true;
   kernelParams = [
     "quiet"
     "boot.shell_on_fail"
   ];
   kernel.sysctl = { "vm.swappiness" = 20; };
   kernelPackages = pkgs.linuxPackages_6_12;
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
   PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin"
   echo -e "\n===================================="
   echo      "| Running nvd diff to show changes |"
   echo -e   "====================================\n"
   nvd diff /run/current-system $systemConfig
   echo ""
 '';

 ### Zram
 zramSwap.enable = true;
 
 ### Zsh
 programs.zsh = {
   enable = true;
   enableBashCompletion = true;
   syntaxHighlighting = {
     enable = true;
   };
   autosuggestions = {
     enable = true;
     strategy = [ "match_prev_cmd" ];
   };
   ohMyZsh = {
     enable = true;
     theme = "agnoster";
   };
   shellAliases = {
     ls = "lsd";
     cat = "bat";
     "cat.ori" = "/run/booted-system/sw/bin/cat";
     "ls.ori" = "/run/booted-system/sw/bin/ls";
     ff = "fastfetch";
     nix = "nix -vL";
     wget = "wget2";
     gc = "git commit";
     gadd = "git add";
     gpush = "git push";
     gpull = "git pull";
    #nix-profile-upgrade = "nix profile upgrade --all";
   };
   interactiveShellInit = ''
    #export NIXOS_VERSION=$(nixos-version | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/')
     export NIXPKGS_ALLOW_UNFREE=1
     export NIXPKGS_COMMIT=$(jq -r '.nodes."nixpkgs".locked.rev' /home/minegame/nixos-configuration/flake.lock|cut -c1-8)
   '';
  };

 ### Nix index
 programs = {
   nix-index = {
     enable = true;
     enableZshIntegration = true;
   };
   command-not-found = {
     enable = false;
   };
 };
 

 ### Fstrim
 services.fstrim.enable = true;
 
 ### Fwupd
 services.fwupd.enable = true;

 ### Nix-ld
 programs.nix-ld.enable = true;
 
 ### GVFS
 services.gvfs.enable = true;

 ### Udev
 services.udev.packages = [ pkgs.gnome-settings-daemon ];

 ### EnvFS
 services.envfs = {
   enable = true;
   extraFallbackPathCommands = ''
     ln -s ${pkgs.bashInteractive}/bin/bash $out/bash
     ln -s ${pkgs.python3}/bin/python3 $out/python
     ln -s ${pkgs.python3}/bin/python3 $out/python3
   '';
 };
 
 ### Qt
 qt = {
   enable = true;
   platformTheme = "gnome";
   style = "adwaita";
 };

 ### binfmt registration
 boot.binfmt.registrations = {
   appimage = {
     wrapInterpreterInShell = false;
     interpreter = "${pkgs.appimage-run}/bin/appimage-run";
     recognitionType = "magic";
     offset = 0;
     mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
     magicOrExtension = ''\x7fELF....AI\x02'';
   };
 };

}
