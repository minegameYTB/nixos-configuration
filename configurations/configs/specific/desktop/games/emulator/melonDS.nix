{ config, pkgs, ... }:

{
 ### Add melonDS
 environment.systemPackages = with pkgs; [ melonDS ];
}
