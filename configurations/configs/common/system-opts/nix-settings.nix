{ config, pkgs, ... }:

{
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
     max-jobs = 2;
     trusted-users = [ "@wheel" ];
     trusted-substituters = [
       "https://hydra.nixos.org/"
     ];
     trusted-public-keys = [
       "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
     ];
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

 system = {
   ### Enable nixos-rebuild-ng to replace nixos-rebuild legacy
   rebuild.enableNg = true;

   ### Disable some nixos other command
   tools = {
     nixos-option.enable = false;
     nixos-build-vms.enable = false;
     nixos-install.enable = false;
   };
 };
}
