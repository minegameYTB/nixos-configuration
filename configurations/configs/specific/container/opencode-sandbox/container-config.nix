{ inputs, stateVersion }:
{
  config,
  pkgs,
  lib,
  ...
}:

let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenvNoCC.system;
  };
in
{
  ### Import configuration from host
  imports = [ ../../../common/system-opts/nix-settings.nix ];

  users.users.minegame = {
    isNormalUser = true;
    initialPassword = "nixos";
    # TODO: Add your dedicated SSH public key
    # Generate one: ssh-keygen -t ed25519 -f ~/.ssh/opencode-sandbox -N ""
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3..." ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  networking = {
    useHostResolvConf = lib.mkForce false;
    firewall.enable = true;
  };
  services.resolved.enable = true;

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
      packages.myVimPackage = with pkgs-unstable.vimPlugins; {
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

  environment.systemPackages = with pkgs-unstable; [
    opencode

    ### Language servers
    bash-language-server
    gopls
    lua-language-server
    marksman
    nil
    nixd
    pyright
    rust-analyzer
    typescript-language-server
    yaml-language-server

    ### Utils
    gcc
    python3
    # (python3.withPackages (pp: with pp; [ ]))
    curl
    file
    git
    jq
    openssl
    rsync
  ];

  system.stateVersion = stateVersion;
}
