{ config, pkgs, ...  }:

{
 ### Flatpak
  systemd.services.flatpak-repo = {
   wantedBy = [ "multi-user.target" ];
   requires = [ "network-online.target" ];
   after = [ "network-online.target" ];
   path = [ pkgs.flatpak ];
   script = ''
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   '';
 };
 
}
