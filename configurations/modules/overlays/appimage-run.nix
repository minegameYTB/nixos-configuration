self: super: {
  appimage-run = super.appimage-run.override {
    extraPkgs = pkgs: with super; [ 
      gnome-console
      ptyxis
      adwaita-icon-theme
    ]; 
  };
}
