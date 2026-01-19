{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import stylix modules like a expression
  imports = [ inputs.stylix.nixosModules.stylix ];

  ### Stylix config
  stylix = {
    enable = config.services.desktopManager.gnome.enable;
    image = "${inputs.dotfiles-minegameYTB}/wallpapers/Wierschem.jpeg";

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
