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
 };

}
