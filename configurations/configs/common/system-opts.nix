{ lib, config, pkgs, ...  }:

{
 ### Boot config
 boot = {
   binfmt = {
     preferStaticEmulators = true;
     emulatedSystems = [
       "aarch64-linux"
     ];
   };
   initrd.systemd = {
     enable = true;
     emergencyAccess = "$y$j9T$CmuNpg/fSyEMO8pehMLwU.$Oe7w2sKzs6teBwP5rU.OOVeGyMAHKL8Pz3JunPlLOv/";
   };
   kernelParams = [
     "quiet"
     "boot.shell_on_fail"
   ];
   kernel.sysctl = { 
     "vm.swappiness" = 20;
   };
   kernelPackages = pkgs.linuxPackages_6_12;
 };
 
 ### Nix Settings
 nix = {
   ### Directory relative to channel are removed with the service "nix-channel-rm-dirs.service"
   channel.enable = false;
  #registry.nix-custom-repo.to = {
  #  owner = "minegameYTB";
  #  repo = "nix-custom-repo";
  #  type = "github";
  #};
   settings = {
     warn-dirty = false;
     auto-optimise-store = true;
     experimental-features = [ "nix-command" "flakes" ];
     trusted-users = [ "minegame" ]; 
     max-jobs = 2;
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

 ### Shell environment
 environment.shellAliases = {
   ls = "lsd";
   cat = "bat";
   df = "df -x tmpfs";
   w-df = "watch df -hx tmpfs";
   "cat.ori" = "/run/booted-system/sw/bin/cat";
   "ls.ori" = "/run/booted-system/sw/bin/ls";
   which = "/run/current-system/sw/bin/which";
   ff = "fastfetch";
   nix = "nix -vL";
   wget = "wget2";
   gc = "git commit";
   gadd = "git add";
   gpush = "git push";
   gpull = "git pull";
   
   ### Use xterm-256color on runtime command
   ssh = "TERM=xterm-256color ssh";
   
   ### This alias is just inspired from macOS "open" command
   open = "xdg-open";
 };

 ### Zsh
 programs.zsh = {
   enable = true;
   enableBashCompletion = true;
   syntaxHighlighting = {
     enable = true;
     highlighters = [
       "main"
     ];
     styles = {
       "comment" = "fg=red,bold";
       "unknown-token" = "fg=red";
     };
   };
   autosuggestions = {
     enable = true;
     strategy = [ "match_prev_cmd" ];
   };
   ohMyZsh = {
     enable = true;
     theme = "agnoster";
   };
   interactiveShellInit = ''
    #export NIXOS_VERSION=$(nixos-version | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/')
     export NIXPKGS_ALLOW_UNFREE=1
   '';
  };

 ### Tmux
 programs.tmux = {
   enable = true;
   terminal = "screen-256color";
   clock24 = true;
   plugins = with pkgs; [
     tmuxPlugins.nord
   ];
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
 
 ### Neovim
 programs.neovim = {
   enable = true;
   viAlias = true;
   withPython3 = false;
   withRuby = false;
   configure = {
     customRC = ''
       colorscheme tokyonight-night
     '';
     packages.myVimPackage = with pkgs.vimPlugins; {
       start = [
         tokyonight-nvim
       ];
     };
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
     ln -s ${pkgs.python3}/bin/python  $out/python
     ln -s ${pkgs.python3}/bin/python3 $out/python3
   '';
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
