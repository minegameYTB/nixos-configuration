{ config, ... }:

{
 ### Autologin   
 services.xserver.displayManager.autoLogin = {
   enable = true;
   user = "minegame";
 };
}
