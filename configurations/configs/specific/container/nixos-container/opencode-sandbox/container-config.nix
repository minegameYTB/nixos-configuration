{
  inputs,
  stateVersion,
  pkgs,
  username,
}:

{
  ### Shared container base (user, SSH + hardening, firewall, git, stateVersion)
  imports = [ (import ../base.nix { inherit stateVersion username; }) ];

  containerBase.git = {
    userName = "Minegame YTB";
    userEmail = "53137994+minegameYTB@users.noreply.github.com";
  };

  environment.systemPackages = with pkgs.pkgsUnstable; [
    #(opencode.override {
    #  bun = pkgs.bun.overrideAttrs (oldAttrs: rec {
    #    version = "1.3.13";
    #    src = pkgs.fetchurl {
    #      url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64-baseline.zip";
    #      hash = "sha256-nYokKSpwaAkCBdqsCloiP19pc29Sh+N7+I07QDHtx1A=";
    #    };
    #  });
    #})
    opencode
    mcp-nixos

    ### Language servers
    bash-language-server
    gopls
    lua-language-server
    marksman
    nixd
    pyright
    rust-analyzer
    typescript-language-server
    yaml-language-server

    ### Utils
    gcc
    python3
    curl
    file
    git
    jq
    openssl
    rsync
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    configure = {
      customRC = ''
        lua << EOF
        vim.cmd("set expandtab")
        vim.cmd("set tabstop=2")
        vim.cmd("set softtabstop=2")
        vim.cmd("set shiftwidth=2")
        vim.o.autoindent = true

        vim.cmd('colorscheme tokyonight-night')

        require("mini.indentscope").setup {
          symbol = "│",
          draw = {
            delay = 0,
            animation = function() return 0 end,
          },
          options = { try_as_border = true },
        }

        require('lualine').setup {
          options = {
            theme = 'tokyonight'
          }
        }

        vim.opt.termguicolors = true
        require("bufferline").setup{}

        require('dashboard').setup {
          theme = 'hyper'
        }
        EOF
      '';
      packages.myVimPackage = with pkgs.pkgsUnstable.vimPlugins; {
        start = [
          tokyonight-nvim
          lualine-nvim
          bufferline-nvim
          mini-indentscope
          dashboard-nvim
        ];
      };
    };
  };
}
