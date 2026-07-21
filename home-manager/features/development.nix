{ config, pkgs, inputs, ... }:

{
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  programs.neovim = {
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  programs.lazyvim = {
    enable = true;
    pluginSource = "nixpkgs";
    ignoreBuildNotifications = true;
    extras = {
      lang.nix.enable = true;
    };
    config = {
      keymaps = ''
        vim.keymap.set({ "n", "x" }, "d", '"_d', { noremap = true, silent = true })
        vim.keymap.set("n", "dd", '"_dd', { noremap = true, silent = true })
        vim.keymap.set("n", "<Del>", '"_x', { noremap = true, silent = true })
        vim.keymap.set("i", "<Del>", '<Esc>"_xi', { noremap = true, silent = true })
        vim.keymap.set("v", "<Del>", '"_x', { noremap = true, silent = true })
      '';
    };
    extraPackages = with pkgs; [
      nixd nixfmt statix gcc tree-sitter
      bash-language-server gopls lua-language-server
      marksman nil pyright rust-analyzer
      typescript-language-server yaml-language-server
    ];
    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [ dtd ];
  };
}
