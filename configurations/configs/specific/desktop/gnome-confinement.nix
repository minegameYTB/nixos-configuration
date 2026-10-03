{
  lib,
  config,
  ...
}:

{
  ### Confine GNOME user services (GNOME only, no CLI impact).
  ### localsearch units follow services.gnome.localsearch.enable,
  ### tinysparql portal follows services.gnome.tinysparql.enable.
  ### Skipped: MemoryDenyWriteExecute, PrivateDevices, RestrictNamespaces,
  ### ProcSubset=pid, IPAddressDeny (break miners/user session).
  systemd.user.services = lib.mkIf config.services.desktopManager.gnome.enable (
    let
      ### Blacklist only, no whitelist (#26913): keeps glib mainloop + keyring working.
      syscallBlacklist = [
        "~@swap"
        "~@obsolete"
        "~@cpu-emulation"
        "~@module"
        "~@mount"
        "~@reboot"
        "~@raw-io"
        "~@debug"
        "~@privileged"
      ];

      ### Miners: no network. CacheDirectory creates DB on pristine homes;
      ### %t/dconf stays writable.
      minerConfine = {
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        CacheDirectory = "tracker3";
        ReadWritePaths = [ "%t/dconf" ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
        ProtectProc = "invisible";
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = syscallBlacklist;
        UMask = "0077";
      };

      ### Evolution: same FS, network kept for sync.
      syncConfine = {
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        StateDirectory = "evolution";
        ConfigurationDirectory = "evolution";
        CacheDirectory = "evolution";
        ReadWritePaths = [ "%t/dconf" ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
        ProtectProc = "invisible";
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = syscallBlacklist;
        UMask = "0077";
      };

      ### rygel/RDP: FS only, network required.
      lightConfine = {
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        UMask = "0077";
      };
    in
    {
      ### writeback fails closed on metadata writes (read-only home).
      "localsearch-3" = lib.mkIf config.services.gnome.localsearch.enable {
        serviceConfig = minerConfine;
      };
      "localsearch-control-3" = lib.mkIf config.services.gnome.localsearch.enable {
        serviceConfig = minerConfine;
      };
      "localsearch-writeback-3" = lib.mkIf config.services.gnome.localsearch.enable {
        serviceConfig = minerConfine;
      };
      "tinysparql-xdg-portal-3" = lib.mkIf config.services.gnome.tinysparql.enable {
        serviceConfig = minerConfine;
      };

      "evolution-source-registry".serviceConfig = syncConfine;
      "evolution-calendar-factory".serviceConfig = syncConfine;
      "evolution-addressbook-factory".serviceConfig = syncConfine;
      "evolution-alarm-notify".serviceConfig = syncConfine;

      "rygel".serviceConfig = lightConfine;
      "gnome-remote-desktop".serviceConfig = lightConfine;
      "gnome-remote-desktop-handover".serviceConfig = lightConfine;
      "gnome-remote-desktop-headless".serviceConfig = lightConfine;
    }
  );
}
