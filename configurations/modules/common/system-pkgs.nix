{ config, pkgs, ...  }:

{      
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
   #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
	micro
    wget2
    efibootmgr
    nvd
    appimage-run
    flatpak
    ntfs3g
    blackbox-terminal
    nautilus-open-in-blackbox
    ptyxis
    git
    virt-viewer
    bat
    lsd
    ayu-theme-gtk
    gparted
    python3
    gnome.gnome-software
    gnome.gnome-tweaks
    papirus-icon-theme
  ];
}
