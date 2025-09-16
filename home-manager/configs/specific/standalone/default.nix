{ lib, config, pkgs, ... }:

{
 ### Nvd diff hook
 home.activation = {
   report-changes = lib.hm.dag.entryAfter ["writeBoundary"] ''
     ### Define strict variable on this context
     export PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin"
     echo -e "\n===================================="
     echo      "| Running nvd diff to show changes |"
     echo -e   "====================================\n"
     ### Variable found in activation script
     nvd diff $HOME/.nix-profile $newGenPath
     echo ""
   '';
 };
}
