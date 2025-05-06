{ config, pkgs, ... }:

{
 ### Common env variable
 environment.variables = {
   EDITOR = "nvim";
 };

 ### Shell environment
 environment.shellAliases = {
   ls = "${pkgs.lsd}/bin/lsd";
   cat = "${pkgs.bat}/bin/bat";
   df = "df -x tmpfs";
   w-df = "watch df -hx tmpfs";
   "cat.ori" = "${pkgs.coreutils-full}bin/cat";
   "ls.ori" = "${pkgs.coreutils-full}/bin/ls";
   which = "/run/current-system/sw/bin/which";
   ff = "fastfetch";
   nix = "nix -v --refresh";
   gc = "git commit";
   gadd = "git add";
   gpush = "git push";
   gpull = "git pull";

   ### Use xterm-256color on runtime command
   ssh = "TERM=xterm-256color ssh";

   ### This alias is just inspired from macOS "open" command
   open = "xdg-open";
 };
}
