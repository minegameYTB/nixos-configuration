{ inputs, lib, config, pkgs, ... }:

{
 ### Initialise nur on home-manager standalone (already the case on hm-module on NixOS)
 nixpkgs.overlays = [ inputs.nur.overlays.default ];
 
 ### Environment variable
 home.sessionVariables = {
   PATH = "$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH";
 };

 home.shellAliases = {
   ### Aliases
   nix = "nix --refresh -v --cores 2";
   home-manager = "home-manager -b bak";

   ### Git alias
   gadd = "git add";
   gpush = "git push";
   gpull = "git pull";
   gc = "git commit";
   gsw = "git switch";
   gbr = "git branch";
   gft = "git fetch";

   ### Core utilities remplacement
   ls = "${pkgs.lsd}/bin/lsd";
   cat = "${pkgs.bat}/bin/bat";
   df = "${pkgs.duf}/bin/duf -hide special";

   ### Original core utilities (from nixpkgs)
   "ls.ori" = "${pkgs.coreutils}/bin/ls";
   "cat.ori" = "${pkgs.coreutils}/bin/cat";
   "df.ori" = "${pkgs.coreutils}/bin/df";

   ### Use xterm-256color on runtime command
   ssh = "TERM=xterm-256color ssh";

   ### This alias is just inspired from macOS "open" command
   open = "${pkgs.xdg-utils}/bin/xdg-open";
 };

 ### Nix package (use nix package from this option)
 home.packages = with pkgs; [ config.nix.package ];

 ### Nvd diff hook
 home.activation = {
   report-changes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
     ### Define strict variable on this context
     export PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin"
     echo -e "\n===================================="
     echo      "| Running nvd diff to show changes |"
     echo -e   "====================================\n"
     ### Variable found in activation script
     nvd diff $oldGenPath $newGenPath
     echo ""
   '';
 };
}
