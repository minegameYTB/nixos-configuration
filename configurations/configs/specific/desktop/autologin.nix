{ lib, config, ... }:

{
 ### Autologin
 services.displayManager.autoLogin = {
   enable = true;
   user = "minegame";
 };

 services.xserver.displayManager.lightdm = {
   enable = lib.mkForce true;
   greeters.gtk.enable = true;
 };

 ### Force disable gdm and sddm (avoid error)
 services.displayManager.sddm.enable = lib.mkForce false;
 services.xserver.displayManager.gdm.enable = lib.mkForce false;
}
