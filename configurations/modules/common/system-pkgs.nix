{ config, pkgs, ...  }:

{      
 # Allow unfree packages
 nixpkgs.config.allowUnfree = true;

 nixpkgs.overlays = [
  #(import ../overlays/coreutils-full.nix) ### Overlays for coreutils-full (just compile tools for users and not runtime deps for software)
  #(import ../overlays/appimage-run.nix) ### Overlays to add some tools on appimage-run rootfs
  #(import ../overlays/gnome-control-center.nix) ### remove libwacom support (don't work as espect...)
  #(import ../overlays/package-name.nix)
 ];

 # List packages installed in system profile. To search, run:
 # $ nix search wget
 environment.systemPackages = with pkgs; [
   ### CLI
   wget2
   jq
   nix-search-cli
   efibootmgr
   ntfs3g
   git
   bat
   lsd

   ### Utilities
   gparted
   gearlever   
   virt-viewer

   ### Other
   ptyxis
   gnome-tweaks

   ### Themes
   papirus-icon-theme
   ayu-theme-gtk

   ### External packages
   (pkgs.callPackage ../../../pkgs/fhsEnv-dev {}) ### fhsEnv-dev (for dev environment require fhs to be used)

   ### Wrapper script
   (pkgs.writeShellScriptBin "nixos-rebuild" ''
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild -L "$@"
   '')
 ];
}
