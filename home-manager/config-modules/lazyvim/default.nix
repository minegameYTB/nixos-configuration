{ config, pkgs, inputs, ... }:

{
  ### Import lazyvim expr
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  ### Setup neovim
  programs.neovim = {
    viAlias = true;
    vimAlias = true;
  };

  ### Setup lazyvim
  programs.lazyvim.enable = true;
}
