{ config, pkgs, ... }:

{
  stylix.targets = {
    # Ghostty is configured with home-manager's native programs.ghostty in
    # hm-profiles/users/minegame/apps.nix instead; stylix's own ghostty target
    # would merge its theme, font and opacity on top of it.
    ghostty.enable = false;
    gnome.enable = true;
    gtksourceview.enable = true;
    gtk = {
      enable = true;
      flatpakSupport.enable = true;
    };
    tmux.enable = false;
    qt.enable = false;
  };
}
