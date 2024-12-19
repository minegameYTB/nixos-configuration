{ config, pkgs, ...  }:

{      
 # Allow unfree packages
 nixpkgs.config.allowUnfree = true;

 nixpkgs.overlays = [
   (import ../overlays/coreutils-full.nix) ### Overlays for coreutils-full (just compile tools for users and not runtime deps for software)
  #(import ../overlays/gnome-control-center.nix) ### remove libwacom support (don't work as espect...)
  #(import ../overlays/package-name.nix)
 ];

 # List packages installed in system profile. To search, run:
 # $ nix search wget
 environment.systemPackages = with pkgs; [
  #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
   wget2
   nix-search-cli
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
   gnome-software
   gnome-tweaks
   nvd
   papirus-icon-theme
 ];
}
