{ inputs, ... }:

{
  ### Import nix-index-detabase module
  imports = [ inputs.nix-index-database.nixosModules.nix-index ];

  ### Nix-index-database install automatically nix-index (with the database)
  ### Not need to install it with environment.systemPackages
}
