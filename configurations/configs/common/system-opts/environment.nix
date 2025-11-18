{ config, pkgs, ... }:

{
 ### Common env variable
 environment.variables = {
   EDITOR = "nvim";
   NIXPKGS_ALLOW_UNFREE = "1";
   VM_OPTS = "$(echo '-smp 2 -m 4096 -spice port=3001,disable-ticketing=on -device virtio-vga -display gtk')";
 };

 ### Shell environment
 environment.shellAliases = {
   ### Core utilities remplacement
   ls = "${pkgs.lsd}/bin/lsd";
   cat = "${pkgs.bat}/bin/bat";
   df = "${pkgs.duf}/bin/duf -hide special";

   ### Original core utilities tools
   "cat.ori" = "/run/current-system/sw/bin/cat";
   "ls.ori" = "/run/current-system/sw/bin/ls --color";
   "df.ori" = "/run/current-system/sw/bin/df";
   
   ### Prevent to use internal which config in zsh (shows aliases which path)
   which = "/run/current-system/sw/bin/which";
   
   ### Rm never interact
   rm = "/run/current-system/sw/bin/rm --interactive=never";
   
   ### Other aliases
   w-df = "/run/current-system/sw/bin/watch ${pkgs.duf}/bin/duf -hide special";
   ff = "${pkgs.fastfetch}/bin/fastfetch";
   nix = "/run/current-system/sw/bin/nix -v";
   
   ### Git aliases
   gadd = "git add";
   gpush = "git push";
   gpull = "git pull";
   gc = "git commit";
   gsw = "git switch";
   gbr = "git branch";
   gft = "git fetch";

   ### This alias is just inspired from macOS "open" command
   open = "/run/current-system/sw/bin/xdg-open";
 };
 
  ### gnu nano
 programs.nano = {
   ### Disable nano to use neovim instead (move this settings to a another file to use this settings...)
   enable = false;
   nanorc = ''
     set autoindent
     set linenumbers 
   '';
 };
}
