{ config, pkgs, ... }:

{
 ### Podman
 virtualisation.podman.enable = true;

 environment.systemPackages = with pkgs; [ distrobox ];
}
