{ lib, config, pkgs, ...  }:

{
 ### Import x11 related expression
 imports = [ ./x11.nix ];
 
 ### enable kde plasma
 services.displayManager.sddm.enable = true;
 services.desktopManager.plasma6.enable = true;
 
 ### ssh ask password program
 programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
 
 ### Qt pinentry
 programs.gnupg.agent = {
   pinentryPackage = pkgs.pinentry-qt;
 };
}
