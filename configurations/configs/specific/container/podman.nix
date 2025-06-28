{ config, pkgs, ... }:

{
 ### Podman
 virtualisation.podman = {
   enable = true;
   dockerCompat = true;
 };

 environment.systemPackages = with pkgs; [ distrobox ];
}
