{ config, pkgs, ...  }:

{      
 # Allow unfree packages
 nixpkgs.config.allowUnfree = true;

 nixpkgs.overlays = [
   (import ../overlays/coreutils-full.nix) ### Overlays for coreutils-full (just compile tools for users and not runtime deps for software)
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
   gnome-software
   gnome-tweaks
   nvd
   papirus-icon-theme
 ];
}
