{ config, pkgs, ... }:

{
 ### Virtualbox
 virtualisation.virtualbox.host = {
   enable = true;
   enableExtensionPack = true;
 };
}
