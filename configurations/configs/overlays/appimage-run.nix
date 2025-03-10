self: super: {
  appimage-run = super.appimage-run.override {
    extraPkgs = pkgs: with super; [ 
      kdePackages.konsole
      gnome-text-editor
      adwaita-icon-theme
    ]; 
  };
}
