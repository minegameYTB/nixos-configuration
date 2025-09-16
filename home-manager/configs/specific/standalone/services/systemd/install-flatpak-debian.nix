{ config, pkgs, ... }:

{
 systemd.user.services.install-flatpak-debian-base = {
   enable = true;
   Unit = {
     Description = "Install Flatpak through the real package manager (apt in this case)";
     WantedBy = [ "graphical.target" ];
   };
   Service = {
     Type = "oneshot";
     ### Write directly the script of this service with a wrapper
     ExecStart = "${pkgs.writeShellScript ''
       if [ ! -f /var/lib/flatpak/.flathub-initialized ]; then
       echo "Installing flatpak (apt method)"

       if ! command -v flatpak >/dev/null; then
         sudo apt update
         sudo apt install -y flatpak
       fi

       sudo mkdir -p /var/lib/flatpak
       #sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
       sudo touch /var/lib/flatpak/.flathub-initialized
       else
         echo "Flatpak already initialized."
       fi
     ''}"
   };
 };
}
