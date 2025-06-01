{ config, pkgs, ... }:

{
 ### Wireguard
 networking.wireguard = {
   enable = true;
 };
}
