{ config, pkgs, ... }:

{
 ### Common env variable
 environment.variables = {
   EDITOR = "nvim";
 };

 ### Shell environment
 environment.shellAliases = {
   ### Core utilities remplacement
   ls = "${pkgs.lsd}/bin/lsd";
   cat = "${pkgs.bat}/bin/bat";
   df = "${pkgs.duf}/bin/duf -hide special";

   ### Original core utilities tools
   "cat.ori" = "${pkgs.coreutils}/bin/cat";
   "ls.ori" = "${pkgs.coreutils}/bin/ls";
   "df.ori" = "${pkgs.coreutils}/bin/df";
   
   ### Prevent to use internal which config in zsh (shows aliases which path)
   which = "${pkgs.which}/bin/which";
   
   ### Other aliases
   w-df = "${pkgs.procps}/bin/watch ${pkgs.duf}/bin/duf -hide special";
   ff = "${pkgs.fastfetch}/bin/fastfetch";
   nix = "nix -v --refresh";
   
   ### Git aliases
   gadd = "git add";
   gpush = "git push";
   gpull = "git pull";
   gc = "git commit";
   gsw = "git switch";
   gbr = "git branch";

   ### Use xterm-256color on runtime command
   ssh = "TERM=xterm-256color ssh";

   ### This alias is just inspired from macOS "open" command
   open = "xdg-open";
 };
}
