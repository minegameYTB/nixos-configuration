{
  lib,
  config,
  ...
}:

{
  ### Confine satellite GNOME services (/ ro, /home real but ro, network cut
  ### where unneeded). GNOME gate only, no CLI impact. Live inventory
  ### (HP-probook): localsearch-3 + evolution×4 ACTIVE (network kept for
  ### Evolution sync); control/writeback, tinysparql-portal, rygel, RDP
  ### inactive (hardened upfront).
  ###
  ### Rejected (audited): MemoryDenyWriteExecute (in-process extraction may
  ### mmap WX), PrivateDevices (needs /dev/dri), RestrictNamespaces +
  ### ProcSubset=pid (user session, miner needs mountinfo), IPAddressDeny
  ### (redundant with AF_UNIX).
  systemd.user.services = lib.mkIf config.services.desktopManager.gnome.enable (
    let
      ### Short blacklist only: no ~@clock/~@timer (glib mainloop, alarms),
      ### no ~@keyring on evolution (secret trousseau), no whitelist (#26913).
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

      ### Indexers, no network. CacheDirectory (not ReadWritePaths) so the DB
      ### is created on pristine homes; %t/dconf writable (ProtectHome also
      ### covers /run/user, dconf DB lives there).
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

      ### Evolution: same FS, network kept. State/Configuration/CacheDirectory
      ### are created on pristine profiles, exempt from ProtectHome=read-only.
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

      ### Light base (rygel/RDP, inactive, network required): FS only.
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
      "localsearch-3".serviceConfig = minerConfine;
      "localsearch-control-3".serviceConfig = minerConfine;
      "localsearch-writeback-3".serviceConfig = minerConfine;
      "tinysparql-xdg-portal-3".serviceConfig = minerConfine;

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
