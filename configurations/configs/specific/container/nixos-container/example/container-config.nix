{
  inputs,
  stateVersion,
  pkgs,
  username,
}:

{
  ### Shared container base (user, SSH + hardening, firewall, git, stateVersion)
  imports = [ (import ../base.nix { inherit stateVersion username; }) ];

  ### Base options — generic template values, adapt to your needs
  ### (see ../base.nix for the full list)
  containerBase = {
    ### Git identity (applied only when both fields are set)
    git = {
      userName = "Your Name";
      userEmail = "your@email.com";
    };

    ### Hardened SSH server (defaults: enable = true, passwordAuth = true)
    ssh = {
      ### Fill in your real public key, then set passwordAuth = false
      # authorizedKeys = [ "ssh-ed25519 AAAA... your@key" ];
      passwordAuth = true;
    };

    ### sudo for the container user (default: false — no root privileges)
    # sudo = false;

    ### TCP ports open in the container firewall (default: [ 22 ])
    # firewall.allowedTCPPorts = [ 22 8080 ];
  };

  ### Container specifics — packages (from the HOST pkgs, so the overlay
  ### is available: pkgs.pkgsUnstable, pkgs.nur, ...)
  environment.systemPackages = with pkgs.pkgsUnstable; [
    curl
    jq
    ripgrep
    tree
  ];

  ### Services example
  # services.postgresql = {
  #   enable = true;
  #   initialDatabases = [{ name = "example"; }];
  #   ensureUsers = [{ name = username; ensurePermissions = { "DATABASE example" = "ALL PRIVILEGES"; }; }];
  # };

  ### Run host binaries inside the container (dev containers)
  programs.nix-ld.enable = true;
}