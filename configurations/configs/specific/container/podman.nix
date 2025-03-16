{ config, pkgs, ... }:

{
 ### Podman
 virtualisation.docker.enable = true;

 #environment.systemPackages = with pkgs; [ distrobox ];
}
