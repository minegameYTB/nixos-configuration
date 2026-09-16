{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  exportEnabled = config.services.nfs.server.enable && config.services.samba.enable;
  isZfs = lib.attrByPath [ "/" "fsType" ] "" config.fileSystems == "zfs";
in

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
  # (https://gitlab.com/librephoenix/nixos-config/-/blob/0324f60ab14f8551b72ea6078562813befc72786/system/security/blocklist.nix)

  # lib.optionals returns a list, but networking.extraHosts (types.lines in
  # current nixpkgs) only accepts strings — on headless profiles
  # (xserver disabled) this produced `[ ]` and broke every headless build.
  networking.extraHosts =
    let
      blocklist = builtins.readFile "${inputs.blocklist}/alternates/fakenews-gambling/hosts";
    in
    lib.mkIf config.services.xserver.enable ''

      ${blocklist}
    '';

  ### Network stack
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  ### Mount /export as tmpfs
  fileSystems."/export" = lib.mkIf exportEnabled {
    fsType = "tmpfs";
    options = [
      "nodev"
      "noexec"
      "nosuid"
      "noswap"
      "mode=755"
      "size=4k"
    ];
  };

  ### ZFS: mount the /export tmpfs before any ZFS dataset below it.
  ### Datasets with a ZFS-native mountpoint (mountpoint=/export/...) are
  ### mounted by zfs-mount.service, outside fstab ordering — force it after
  ### export.mount so it can never cover the tmpfs.
  systemd.services."zfs-mount" = lib.mkIf (exportEnabled && isZfs) {
    after = [ "export.mount" ];
    wants = [ "export.mount" ];
  };

  ### Legacy datasets (fileSystems."/export/..." with fsType = "zfs") are
  ### ordered after their parent by systemd, but enforce an explicit
  ### `depends = [ "/export" ]` so the ordering survives refactors.
  assertions = lib.optionals exportEnabled (
    let
      exportChildren = lib.filterAttrs (n: _: lib.hasPrefix "/export/" n) config.fileSystems;
      missing = lib.filterAttrs (n: v: !(lib.elem "/export" v.depends)) exportChildren;
    in
    [
      {
        assertion = missing == { };
        message = "fileSystems under /export must set depends = [ \"/export\" ] so the /export tmpfs mounts first (offenders: ${lib.concatStringsSep ", " (builtins.attrNames missing)})";
      }
    ]
  );
}
