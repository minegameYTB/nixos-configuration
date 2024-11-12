{ config, ... }:

{
 ### Autologin   
 services.displayManager.autoLogin = {
   enable = true;
   user = "minegame";
 };
}
