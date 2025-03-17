{ config, pkgs, ... }:

{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 home.packages = with pkgs; [
   ### Theme
   adw-gtk3
   catppuccin-cursors.mochaDark
 ];

 ### Import conf file for cli software
 home.file = {
   ".screenrc".source = ../../dotfiles/config-file/screen/screenrc;
   ".config/fastfetch/config.jsonc".source = ../../dotfiles/config-file/fastfetch/config.jsonc;
 };
 
 programs.neovim = {
   enable = true;
   viAlias = true;
   withPython3 = false;
   withRuby = false;
   defaultEditor = true;
   extraPackages = with pkgs; [
     xclip 
     wl-clipboard
   ];
   plugins = with pkgs.vimPlugins; [
     ### Install plugins to use with this configuration
     tokyonight-nvim
     lualine-nvim
     nvim-treesitter
     nvim-treesitter.withAllGrammars
   ];
   extraLuaConfig = ''
     vim.cmd("set expandtab")
     vim.cmd("set tabstop=2")
     vim.cmd("set softtabstop=2")
     vim.cmd("set shiftwidth=2")
     vim.cmd('colorscheme tokyonight-night')

     require('lualine').setup {
       options = {
         theme = 'tokyonight'
       }
     }
   '';
 };

}
