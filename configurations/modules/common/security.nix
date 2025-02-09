{ config, pkgs, ... }:

{
   # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
   #enableSSHSupport = true;
  };
  
 ### Apparmor
#security.apparmor.enable = true;
}
