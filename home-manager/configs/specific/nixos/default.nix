{ username, ... }:

{
  ### Import nixos specific expression (controlled by home-manager)
  imports = [
    ./stylix.nix
  ];
}
