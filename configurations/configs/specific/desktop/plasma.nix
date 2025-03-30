{ lib, config, pkgs, ...  }:

{
 ### Import x11 related expression
 imports = [ ./x11.nix ];
 
 services.desktopManager.plasma6.enable = true;
 
 ### ssh ask password program
 programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
 
 ### Qt pinentry
 programs.gnupg.agent = {
   pinentryPackage = pkgs.pinentry-qt;
 };
}
