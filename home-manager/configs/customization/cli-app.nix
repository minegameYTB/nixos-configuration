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
   defaultEditor = true;
   extraPackages = with pkgs; [
     xclip 
     wl-clipboard
   ];
   plugins = with pkgs.vimPlugins; [
     tokyonight-nvim
     lualine-nvim
   ];
   extraConfig = ''
     set backspace=indent,eol,start
   '';
   extraLuaConfig = ''
     vim.cmd('colorscheme tokyonight-night')
    
     require('lualine').setup {
       options = {
         theme = 'tokyonight'
       }
     }
   '';
 };

}
