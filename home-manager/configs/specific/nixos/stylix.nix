{ config, pkgs, ... }:

{
  ### stylix
  stylix = {
    targets = {
      tmux.enable = false;
      ### Remove warning for qtct
      qt = {
        enable = false;
        #platform = "qtct";
      };
    };
  };

}
