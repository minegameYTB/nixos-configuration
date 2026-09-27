{
  lib,
  config,
  ...
}:

{
  ### Mount-namespace confinement for satellite GNOME services (N1).
  ### Principle: / read-only (ProtectSystem=strict ~ tmpfs without manual
  ### re-mounts), /home re-mounted real but read-only, DB re-opened RW,
  ### secrets hidden, network cut where the function does not require it.
  ### GNOME gate only — no impact on CLI/servers.
  ###
  ### Live inventory (HP-probook, 2026-09-27):
  ### - localsearch-3 ACTIVE (indexer, root=/ cwd=/home/minegame, live DB at
  ###   ~/.cache/tracker3/files/meta.db-wal) — real systemd user unit,
  ###   systemd.user.services drop-ins apply (no D-Bus bypass).
  ### - evolution-*-factory (4) ACTIVE (GNOME Calendar in use) — Type=dbus
  ###   units, network KEPT (Online Accounts sync), FS confined only.
  ### - localsearch-control/writeback, tinysparql-xdg-portal-3, rygel,
  ###   gnome-remote-desktop*: unit files present but INACTIVE — profile
  ###   applied upfront, effective only if ever started.
  ###
  ### Deliberately NOT set (audited against
  ### ~/Projets/github/nix-system-services-hardened, rejected with reason):
  ### - MemoryDenyWriteExecute: in-process metadata extraction may mmap WX —
  ###   would fail silently. Re-test on a full extraction cycle before use.
  ### - PrivateDevices / DevicePolicy=closed: /dev/dri needed for video
  ###   metadata extraction (VA-API).
  ### - RestrictNamespaces: premature in a user session (D-Bus activation,
  ###   helpers) — prove in VM first.
  ### - IPAddressDeny: redundant with RestrictAddressFamilies=[ "AF_UNIX" ].
  ### - SystemCallFilter: v2, short blacklist only, never ~@clock on evolution
  ###   (alarm-notify needs timers). Prove in VM first.
  systemd.user.services = lib.mkIf config.services.desktopManager.gnome.enable (
    let
      ### Indexer base: no network need (AF_UNIX = D-Bus bus only),
      ### $HOME readable for indexing, writes limited to the DB.
      ### CacheDirectory (not ReadWritePaths): systemd CREATES ~/.cache/tracker3
      ### at startup even on a pristine $HOME (VM reset) — ReadWritePaths on a
      ### nonexistent path creates nothing, the miner cannot init its DB and
      ### ~/.cache/tracker3 never appears.
      minerConfine = {
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        CacheDirectory = "tracker3";
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
        UMask = "0077";
      };

      ### Base for network-sync services (Evolution): same FS, network kept.
      ### State/Configuration/CacheDirectory: created under
      ### $XDG_{DATA,CONFIG,CACHE}_HOME even on a pristine profile,
      ### exempt from ProtectHome=read-only.
      syncConfine = {
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        StateDirectory = "evolution";
        ConfigurationDirectory = "evolution";
        CacheDirectory = "evolution";
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
        UMask = "0077";
      };

      ### Light base (rygel/rdp, inactive, network required by function):
      ### hardened FS only, network deliberately kept. Tighten the profile
      ### on the day of a real activation.
      lightConfine = {
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        UMask = "0077";
      };
    in
    {
      ### Indexer + companions (strict profile, no network).
      ### Note: localsearch-writeback writes metadata INTO the indexed files —
      ### read-only fails closed (no persisted Nautilus notes/tags).
      ### Relax towards syncConfine if needed.
      "localsearch-3".serviceConfig = minerConfine;
      "localsearch-control-3".serviceConfig = minerConfine;
      "localsearch-writeback-3".serviceConfig = minerConfine;
      "tinysparql-xdg-portal-3".serviceConfig = minerConfine;

      ### Evolution (confined FS, network kept for sync).
      "evolution-source-registry".serviceConfig = syncConfine;
      "evolution-calendar-factory".serviceConfig = syncConfine;
      "evolution-addressbook-factory".serviceConfig = syncConfine;
      "evolution-alarm-notify".serviceConfig = syncConfine;

      ### Inactives: light hardening, network kept (function requires it).
      "rygel".serviceConfig = lightConfine;
      "gnome-remote-desktop".serviceConfig = lightConfine;
      "gnome-remote-desktop-handover".serviceConfig = lightConfine;
      "gnome-remote-desktop-headless".serviceConfig = lightConfine;
    }
  );
}
