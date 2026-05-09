{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # List services that you want to enable:

  #Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  ### BlockList (https://github.com/StevenBlack/hosts)
  ### (https://gitlab.com/librephoenix/nixos-config/-/blob/0324f60ab14f8551b72ea6078562813befc72786/system/security/blocklist.nix)
  networking.extraHosts =
    let
      blocklist = builtins.readFile "${inputs.blocklist}/alternates/fakenews-gambling/hosts";
    in
    if config.services.xserver.enable then
      ''

        ${blocklist}
      ''
    else
      "";

  ### Network stack
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;
}
