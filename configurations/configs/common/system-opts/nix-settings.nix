{ config, pkgs, pkgsExtra, inputs, ... }:

{
 ### Nix Settings
 nix = {
   ### Use nix from ctrl os
   package = pkgsExtra.pkgs-lts.nix;

   ### Directory relative to channel are removed with the service "nix-channel-rm-dirs.service"
   channel.enable = false;
   registry = {
     ctrlos.to = {
       type = "path";
       path = inputs.ctrl-os;
     };
   };
  #registry.nix-custom-repo.to = 
  #  owner = "minegameYTB";
  #  repo = "nix-custom-repo";
  #  type = "github";
  #};
   settings = {
     warn-dirty = false;
     auto-optimise-store = true;
     experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
     max-jobs = 2;
     cores = 2;
     
     ### Substituers settings
     trusted-users = [ "@wheel" ];
     substituters = [
       "https://cache.ctrl-os.com/"
     ];
     trusted-substituters = [
       "https://cache.ctrl-os.com/"
     ];
     trusted-public-keys = [
       "ctrl-os:baPzGxj33zp/P+GAIJXsr8ss9Law+qEEFViX1+flbv8="
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
   ### Enable nixos-rebuild-ng to replace nixos-rebuild legacy (take "config.system.tools.nixos-rebuild.enable" value to use value defind in this option as true)
   #rebuild.enableNg = config.system.tools.nixos-rebuild.enable; ### Remove this line in 26.05 release

   ### Disable some nixos other command
   tools = {
     nixos-option.enable = false;
     nixos-build-vms.enable = false;
     nixos-install.enable = false;
   };
 };
}
