{
  lib,
  config,
  ...
}:

{
  ### Mount-namespace confinement for satellite GNOME services.
  ### / read-only, /home real but read-only (DBs re-opened RW), network cut
  ### where the function does not need it. GNOME gate only, no CLI impact.
  ###
  ### Live inventory (HP-probook): localsearch-3 ACTIVE; evolution×4 ACTIVE
  ### (Calendar in use → network kept); control/writeback, tinysparql-portal,
  ### rygel, RDP present but inactive (hardened upfront, effective on start).
  ###
  ### Rejected (audited, see ~/Projets/github/nix-system-services-hardened):
  ### MemoryDenyWriteExecute (in-process extraction may mmap WX),
  ### PrivateDevices/DevicePolicy (needs /dev/dri), RestrictNamespaces
  ### (premature in user sessions), IPAddressDeny (redundant with AF_UNIX),
  ### ProcSubset=pid (would hide /proc/self/mountinfo from the miner).
  systemd.user.services = lib.mkIf config.services.desktopManager.gnome.enable (
    let
      ### Indexers: no network (AF_UNIX = D-Bus only). CacheDirectory — not
      ### ReadWritePaths — so systemd creates ~/.cache/tracker3 on pristine
      ### homes. %t/dconf stays writable: ProtectHome=read-only also covers
      ### /run/user, and every GNOME service writes its dconf DB there
      ### (without it: "unable to create file '/run/user/.../dconf/user'").
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
        SystemCallFilter = [
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
        UMask = "0077";
      };

      ### Evolution: same FS, network kept for sync. State/Configuration/
      ### CacheDirectory are created on pristine profiles and exempt from
      ### ProtectHome=read-only. No ~@clock/~@timer/~@keyring in the filter
      ### (glib mainloop, alarms, secret trousseau).
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
        SystemCallFilter = [
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
        UMask = "0077";
      };

      ### Light base (rygel/RDP, inactive, network required): hardened FS
      ### only. Tighten on the day of a real activation.
      lightConfine = {
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        UMask = "0077";
      };
    in
    {
      ### writeback fails closed on metadata writes (read-only home) —
      ### no persisted Nautilus notes/tags. Relax if needed.
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
