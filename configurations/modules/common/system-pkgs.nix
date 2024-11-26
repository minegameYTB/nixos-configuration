{ config, pkgs, ...  }:

{      
 # Allow unfree packages
 nixpkgs.config.allowUnfree = true;

 nixpkgs.overlays = [
   (import ../overlays/coreutils-full.nix)
  #(import ../overlays/package-name.nix)
 ];

 # List packages installed in system profile. To search, run:
 # $ nix search wget
 environment.systemPackages = with pkgs; [
  #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
   micro
   wget2
   efibootmgr
   appimage-run
   flatpak
   ntfs3g
   ptyxis
   git
   virt-viewer
   bat
   lsd
   ayu-theme-gtk
   gparted
   gnome.gnome-software
   gnome.gnome-tweaks
   papirus-icon-theme
 ];
}
