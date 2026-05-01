{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import lazyvim expr
  imports = [ inputs.lazyvim.homeManagerModules.default ];

  ### Setup neovim
  programs.neovim = {
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  ### Setup lazyvim
  programs.lazyvim = {
    enable = true;
    pluginSource = "nixpkgs";
    extras = {
      lang.nix.enable = true;
    };
    config = {
      keymaps = ''
        -- Disable yank on copy
        vim.keymap.set({ "n", "x" }, "d", '"_d', { noremap = true, silent = true })
        vim.keymap.set("n", "dd", '"_dd', { noremap = true, silent = true })

        -- Same for "c"
        -- vim.keymap.set({ "n", "x" }, "c", '"_c', { noremap = true, silent = true })

        -- Same for <Del>
        vim.keymap.set("n", "<Del>", '"_x', { noremap = true, silent = true })
        vim.keymap.set("i", "<Del>", '<Esc>"_xi', { noremap = true, silent = true })
        vim.keymap.set("v", "<Del>", '"_x', { noremap = true, silent = true })
      '';
    };
    extraPackages = (
      with pkgs;
      [
        nixd # Nix LSP
        nixfmt # Nix formatter
        statix # For suggestion on nix files
        gcc # Provides the C Compiler
        tree-sitter # Provides the tree-sitter CLI
      ]
    );
    treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [ dtd ];
  };
}
