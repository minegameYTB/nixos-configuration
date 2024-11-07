{ config, pkgs, ...  }:

{      
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
   #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    efibootmgr
    nvd
    flatpak
    ntfs3g
    ptyxis
    virt-viewer
    bat
    lsd
    ayu-theme-gtk
    gnome.gnome-software
    gnome.gnome-tweaks
    gparted
    papirus-icon-theme
  ];
  
}
