{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import stylix modules like a expression
  imports = [ inputs.stylix.nixosModules.stylix ];

  ### Ccache related options
  programs.ccache.packageNames = [
    "gdm"
    "gnome-shell"
    "gnome-text-editor"
    "gnome-calculator"
    "gnome-session"
    "gnome-initial-setup"
    "sushi"
    "papers"
    "gtksourceview4"
    "gtksourceview5"
  ];

  ### Stylix config
  stylix = {
    enable = true;
    image = "${inputs.dotfiles-minegameYTB}/wallpapers/Custom/Matt-manual-upscale-1920x1080.png";

    ### Catppucin wallpaper
    #"${inputs.catppuccin-wallpapers}/landscapes/Cloudsnight.jpg";

    ### Accept fetchurl derivation (see stylix doc)
    #image = pkgs.fetchurl {
    #  url = "";
    #  sha256 = "";
    #};
    polarity = "dark";
    fonts = {
      sansSerif = {
        ### Use pkgsExtra.pkgs-unstable to get adwaita-fonts (even if i use nixpkgs stable by default)
        package = pkgs.adwaita-fonts;
        name = "Adwaita Sans";
      };
      serif = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Sans";
      };
      monospace = {
        package = pkgs.adwaita-fonts;
        name = "Adwaita Mono";
      };
      sizes.applications = 11;
    };
    #base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    cursor = {
      ### Use nixpkgs stable for this package
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
    };
    targets = {
      plymouth = {
        enable = true;
        logoAnimated = false;
      };
    };
  };
}
