{ lib, config, ... }:

{
 ### Autologin
 services.displayManager.autoLogin = {
   enable = true;
   user = "minegame";
 };

 services.xserver.displayManager.lightdm = {
   enable = lib.mkDefault true;
   greeters.gtk.enable = true;
 };
}
