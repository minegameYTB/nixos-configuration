{
  inputs,
  stateVersion,
  pkgs,
  username,
}:
{
  config,
  lib,
  ...
}:

{
  ### Import configuration from host
  imports = [ ../../../common/system-opts/nix-settings.nix ];

  users.users.${username} = {
    isNormalUser = true;
    initialPassword = "nixos";
    # TODO: Add your dedicated SSH public key
    # Generate one: ssh-keygen -t ed25519 -f ~/.ssh/opencode-sandbox -N ""
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3..." ];
  };

  ### Disable sudo in the container (security: no root privileges needed for opencode/LSPs)
  security.sudo.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # SSH service hardening
  systemd.services.sshd.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    PrivateTmp = true;
  };

  networking = {
    useHostResolvConf = lib.mkForce false;
    firewall = {
      enable = true;
      allowedTCPPorts = lib.mkForce [ 22 ];
    };
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

  environment.systemPackages = with pkgs.pkgsUnstable; [
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
