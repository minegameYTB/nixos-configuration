{ config, pkgs, ...  }:

      
 let
   ### Add external packages
   fhsEnv-dev = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
   
   ### Wrapper script
   nixos-rebuild = pkgs.writeShellScriptBin "nixos-rebuild" ''
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild -L "$@"
   '';
 in
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
   ghostty
   gnome-tweaks

   ### Themes
   papirus-icon-theme
   ayu-theme-gtk

   ### External packages
   fhsEnv-dev

   ### Wrapper script
   nixos-rebuild
 ];
}
