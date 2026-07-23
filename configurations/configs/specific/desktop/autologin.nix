{ lib, config, ... }:

{
  ### Autologin (display manager agnostic — DM is set by the desktop environment module)
  services.displayManager.autoLogin = {
    enable = true;
    user = "minegame";
  };

  ### Disable GDM fix autologin bug
  services.displayManager.gdm.enable = lib.mkForce false;
}
