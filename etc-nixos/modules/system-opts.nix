{ config, pkgs, ...  }:

{

  ### /tmp
  boot.tmp.cleanOnBoot = true;

 ### Plymouth
 boot.plymouth = {
   enable = true;
   theme = "bgrt";
 };

 ### Kernel
 boot.kernelParams = [
   "quiet"
   "splash"
   "boot.shell_on_fail"
 ];

 ### Nix GC
 nix.settings.auto-optimise-store = true;

 nix.optimise = {
   automatic = true;
   dates = [ "weekly" ];
 };

 nix.gc = {
   automatic = true;
   dates = "weekly";
   options = "--delete-older-than 7d";
 };

 ### Nix Experimental
 nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
 ### Zram
 zramSwap.enable = true;

 ### Flatpak
 services.flatpak.enable = true;
 xdg.portal.enable = true;
    
 systemd.services.flatpak-repo = {
   wantedBy = [ "multi-user.target" ];
   path = [ pkgs.flatpak ];
   script = ''
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   '';
 };

 ### Exclude Xterm
 services.xserver.excludePackages = with pkgs; [
   xterm
 ];

 ### Exclude some Gnome default packages
 environment.gnome.excludePackages = with pkgs; [
   gnome.geary  ### Geary
   gnome-tour   ### Gnome Tour
   epiphany     ### Gnome Web
 ];

}
