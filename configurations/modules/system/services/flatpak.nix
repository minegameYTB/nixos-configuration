{ lib, config, pkgs, ...  }:

{
 ### Flatpak
 systemd.services.flatpak-repo = {
   wantedBy = [ "multi-user.target" ];
   requires = [ "network-online.target" ];
   after = [ "network-online.target" ];
   environment = lib.mkForce {
     PATH = "${pkgs.flatpak}/bin";
    };
   script = ''
     flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   '';
 };

 environment.systemPackages = with pkgs; [ flatpak gnome-software ];
 
}
