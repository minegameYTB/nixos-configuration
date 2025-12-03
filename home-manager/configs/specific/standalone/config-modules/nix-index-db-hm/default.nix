{ inputs, ... }:

{
  ### Import nix-index-detabase module
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  ### Configure Nix index
  programs.nix-index.enable = true;
}
