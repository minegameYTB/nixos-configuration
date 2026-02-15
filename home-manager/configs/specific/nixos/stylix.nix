{ config, pkgs, ... }:

{
  ### stylix
  stylix = {
    targets = {
      ghostty.enable = true;
      gnome.enable = true;
      gtksourceview.enable = true;
      gtk = {
        enable = true;
        flatpakSupport.enable = true;
      };
      tmux.enable = false;
      qt = {
        ### Remove warning for qtct
        enable = false;
        #platform = "qtct";
      };
    };
  };

}
