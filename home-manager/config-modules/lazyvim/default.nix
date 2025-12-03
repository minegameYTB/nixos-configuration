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
  };

  ### Setup lazyvim
  programs.lazyvim = {
    enable = true;
    extras = {
      lang.nix.enable = true;
    };
    extraPackages = with pkgs; [
      nixd # Nix LSP
      nixfmt # Nix formatter
      statix # For suggestion on nix files
      gcc # Provides the C Compiler
      tree-sitter # Provides the tree-sitter CLI
    ];
  };
}
