### Shared base module for container-internal NixOS configs.
### Imported by each container's container-config.nix:
###   imports = [ (import ../base.nix { inherit stateVersion username; }) ];
{
  stateVersion,
  username,
  ...
}:

{
  config,
  lib,
  ...
}:

let
  cfg = config.containerBase;
in
{
  ### Import configuration from host
  imports = [ ../../../common/system-opts/nix-settings.nix ];

  options.containerBase = {
    ### Git identity (only applied when both fields are set)
    git.userName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git user name used by the container.";
    };
    git.userEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git user email used by the container.";
    };

    ssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the hardened SSH server in the container.";
    };
    ssh.authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys for ${username}.";
    };
    ssh.passwordAuth = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow password authentication over SSH.";
    };

    sudo = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sudo in the container (default: no root privileges).";
    };

    firewall.allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 22 ];
      description = "TCP ports open in the container firewall.";
    };
  };

  config = {
    users.users.${username} = {
      isNormalUser = true;
      initialPassword = "nixos";
      openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;
    };

    security.sudo.enable = cfg.sudo;

    services.openssh = lib.mkIf cfg.ssh.enable {
      enable = true;
      settings = {
        PasswordAuthentication = cfg.ssh.passwordAuth;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    ### SSH service hardening
    systemd.services.sshd.serviceConfig = lib.mkIf cfg.ssh.enable {
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
    };

    networking = {
      useHostResolvConf = lib.mkForce false;
      firewall = {
        enable = true;
        allowedTCPPorts = lib.mkForce cfg.firewall.allowedTCPPorts;
      };
    };
    services.resolved.enable = true;

    programs.git = lib.mkIf (cfg.git.userName != null && cfg.git.userEmail != null) {
      enable = true;
      lfs.enable = true;
      config = {
        user.name = cfg.git.userName;
        user.email = cfg.git.userEmail;
        init.defaultBranch = "flake";
      };
    };

    system.stateVersion = stateVersion;
  };
}
