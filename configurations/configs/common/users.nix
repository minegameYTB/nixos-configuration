{ config, pkgs, ...  }:

{
 ### Shell replacement
 users.defaultUserShell = pkgs.zsh;
 
 # Define a user account. Don't forget to set a password with ‘passwd’.
 users.users.minegame = {
   description = "Minegame YTB";
   isNormalUser = true;
   extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" "input" ];
   initialPassword = "nixos";
 };

}
