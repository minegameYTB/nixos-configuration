{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import stylix module
  imports = [ inputs.stylix.nixosModules.stylix ];

  ### Stylix config (enable follows GNOME activation)
  stylix = {
    enable = config.services.desktopManager.gnome.enable;
    image = "${inputs.dotfiles-minegameYTB}/wallpapers/Wierschem.jpeg";
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
      package = pkgs.pkgs2511.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
    };
    autoEnable = false;
    overlays.enable = true;
    targets = {
      gnome.enable = true;
      gnome-text-editor.enable = true;
      gtk.enable = true;
      gtksourceview.enable = true;
      qt.enable = true;
      fontconfig.enable = true;
      console.enable = true;
      plymouth = {
        enable = true;
        logoAnimated = false;
      };
    };
  };

  ### Patch gnome-shell (disable dark mode option)
  #nixpkgs.overlays = [
  #  (self: super: {
  #    gnome-shell = super.gnome-shell.overrideAttrs (oldAttrs: {
  #      patches = (oldAttrs.patches or [ ]) ++ [
  #        "${inputs.stylix}/modules/gnome/shell_remove_dark_mode.patch"
  #      ];
  #    });
  #  })
  #];
}
