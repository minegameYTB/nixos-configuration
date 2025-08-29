{ config, pkgs, pkgsExtra, inputs, ... }:

{
 ### Import conf file for cli software
 home.file = {
   #".screenrc".source = "${inputs.dotfiles-minegameYTB}/configs/screen/screenrc";
 };

 xdg.configFile = {
   "fastfetch/config.jsonc".source = "${inputs.dotfiles-minegameYTB}/configs/fastfetch/config.jsonc";
 };

 programs.neovim = {
   enable = true;
   #package = pkgsExtra.pkgs-24-11.neovim-unwrapped;
   viAlias = true;
   vimAlias = true;
   withPython3 = false;
   withRuby = false;
   defaultEditor = true;
   extraPackages = with pkgs; [
     xclip 
     wl-clipboard
     
     ### For Telescope
     fd
   ];
   plugins = with pkgs.vimPlugins; [
     ### Install plugins to use with this configuration
     tokyonight-nvim
     lualine-nvim
     bufferline-nvim
     mini-indentscope
     
     ### Telescope dependency
     telescope-nvim
     nvim-treesitter.withAllGrammars

     ### Aesthetic plugin
     dashboard-nvim
   ];
   extraLuaConfig = ''
     -- Nvim config
     vim.cmd("set expandtab")
     vim.cmd("set tabstop=2")
     vim.cmd("set softtabstop=2")
     vim.cmd("set shiftwidth=2")
     vim.o.autoindent = true

     -- Theme
     vim.cmd('colorscheme tokyonight-night')

     -- mini-indentscope
     require("mini.indentscope").setup {
       symbol = "│",
       draw = {
         delay = 0,
         animation = function() return 0 end,
       },
       options = { try_as_border = true },
     }

     -- Lualine
     require('lualine').setup {
       options = {
         theme = 'tokyonight'
       }
     }
   
     -- BufferLine config
     vim.opt.termguicolors = true
     require("bufferline").setup{}

     -- Telescope
     vim.keymap.set("n", "<space>fd", require('telescope.builtin').find_files)
    
     -- Nvim dashboard
     require('dashboard').setup {
       -- config
       theme = 'hyper'
     }
   '';
 };

}
