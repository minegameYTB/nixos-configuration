{ config, pkgs, ... }:

{
  ### Tmux
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    clock24 = true;
    plugins = with pkgs; [
      tmuxPlugins.nord
    ];
  };

  ### Neovim
  programs.neovim = {
    enable = true;
    viAlias = true;
    withPython3 = false;
    withRuby = false;
    configure = {
      customRC = ''
        colorscheme tokyonight-night
      '';
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          tokyonight-nvim
        ];
      };
    };
  };
}
