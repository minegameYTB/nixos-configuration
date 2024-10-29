{ config, pkgs, ...  }:

{
 ### Fish root
 users.users.root.shell = pkgs.fish;
 
 # Define a user account. Don't forget to set a password with ‘passwd’.
 users.users.minegame = {
   description = "Minegame YTB";
   isNormalUser = true;
   extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" ];
   initialPassword = "nixos";
   shell = pkgs.fish;
   packages = with pkgs; [
     thunderbird
     fastfetch
     nmon
     adw-gtk3
     testdisk
    #tree
     discord
     spotify
     vlc
     libreoffice-fresh
     prismlauncher
     vscode-fhs
     blender
     rpi-imager
     lsd
     bat
     bottles
     localsend
     gitg
     gnome-extension-manager
   ];
 };

}
