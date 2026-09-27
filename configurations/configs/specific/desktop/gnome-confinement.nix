{
  lib,
  config,
  ...
}:

{
  ### Confinement mount-namespace des services GNOME satellites (N1).
  ### Principe : / en lecture seule (ProtectSystem=strict ~ tmpfs sans remontées
  ### manuelles), /home remonté réel mais read-only, DB ré-ouverte en RW,
  ### secrets masqués, réseau coupé là où la fonction ne l'exige pas.
  ### Gate GNOME only — no impact CLI/serveurs.
  ###
  ### Inventaire live (HP-probook, 2026-09-27) :
  ### - localsearch-3 ACTIVE (indexeur, root=/ cwd=/home/minegame, DB active
  ###   ~/.cache/tracker3/files/meta.db-wal) — vraie unité user systemd,
  ###   les drop-ins systemd.user.services s'appliquent (pas de bypass D-Bus).
  ### - evolution-*-factory (4) ACTIVES (Calendrier GNOME utilisé) — unités
  ###   Type=dbus, réseau GARDÉ (sync Online Accounts), FS confiné seul.
  ### - localsearch-control/writeback, tinysparql-xdg-portal-3, rygel,
  ###   gnome-remote-desktop* : unit files présentes mais INACTIVES — profil
  ###   appliqué d'avance, effet seulement si démarrées un jour.
  systemd.user.services = lib.mkIf config.services.desktopManager.gnome.enable (
    let
      ### Socle indexeurs : aucun besoin réseau (AF_UNIX = bus D-Bus seul),
      ### $HOME lisible pour indexer, écriture limitée à la DB.
      ### CacheDirectory (et non ReadWritePaths) : systemd CRÉE ~/.cache/tracker3
      ### au démarrage même sur un $HOME vierge (VM reset) — ReadWritePaths
      ### sur un chemin inexistant ne crée rien, le miner ne peut pas initier
      ### sa DB et ~/.cache/tracker3 n'apparaît jamais.
      minerConfine = {
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        CacheDirectory = "tracker3";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        LockPersonality = true;
        RestrictRealtime = true;
      };

      ### Socle services à sync réseau (Evolution) : même FS, réseau gardé.
      ### State/Configuration/CacheDirectory : créés sous $XDG_{DATA,CONFIG,CACHE}_HOME
      ### même sur profil vierge, exemptés de ProtectHome=read-only.
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
      };

      ### Socle léger (rygel/rdp, inactifs, réseau requis par fonction) :
      ### FS durci seul, réseau volontairement gardé. Profil complet à
      ### resserrer le jour d'une activation réelle.
      lightConfine = {
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    in
    {
      ### Indexeur + compagnons (profil strict, pas de réseau).
      ### Note : localsearch-writeback écrit les métadonnées DANS les fichiers
      ### indexés — en read-only il échoue fermé (pas de notes/étiquettes
      ### Nautilus persistées). Relâcher vers syncConfine si besoin.
      "localsearch-3".serviceConfig = minerConfine;
      "localsearch-control-3".serviceConfig = minerConfine;
      "localsearch-writeback-3".serviceConfig = minerConfine;
      "tinysparql-xdg-portal-3".serviceConfig = minerConfine;

      ### Evolution (FS confiné, réseau gardé pour la sync).
      "evolution-source-registry".serviceConfig = syncConfine;
      "evolution-calendar-factory".serviceConfig = syncConfine;
      "evolution-addressbook-factory".serviceConfig = syncConfine;
      "evolution-alarm-notify".serviceConfig = syncConfine;

      ### Inactifs : durcissement léger, réseau gardé (fonction l'exige).
      "rygel".serviceConfig = lightConfine;
      "gnome-remote-desktop".serviceConfig = lightConfine;
      "gnome-remote-desktop-handover".serviceConfig = lightConfine;
      "gnome-remote-desktop-headless".serviceConfig = lightConfine;
    }
  );
}
