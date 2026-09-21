# configurations/modules/misc/auto-update/default.nix — GLF-OS style automatic
# system updates: a machine follows the CI-composed *buffer* branch and stages
# new generations with `nixos-rebuild boot` (no immediate activation).
#
# Layout (one concern per file, contracts in each header):
#   errors.nix      — CODE -> FR/EN catalogue + _err_lookup generator
#   output.nix      — { core, render, full }: _status, logging, git filter
#   notifier.nix    — { user, full }: queue/deliver/notify/failure (bilingual)
#   transaction.nix — state machine: lock, traps, phases, recovery, _fail
#   sync.nix        — channel force-sync, flake inputs, rebuild (network/build)
#   health.nix      — post-boot validation (the `validating` phase)
#   default.nix     — this file: options + assertions
#   services.nix    — systemd assembly + main flows (imports the fragments)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system.autoUpdate;

  ### Repo location parsed once (forge-agnostic: GitHub, GitLab, generic
  ### git) — lib/repo.nix stays the single source of truth for the URL.
  repo = import ../../../../lib/repo-info.nix {
    url = (import ../../../../lib/repo.nix).url;
    inherit (cfg) channel;
  };
in
{
  options.system.autoUpdate = {
    enable = lib.mkEnableOption "automatic system updates from a channel branch (GLF-OS style)";

    channel = lib.mkOption {
      type = lib.types.str;
      default = "flake-autoupdate";
      description = "Channel branch followed by auto-update: the last soaked-green source commit (pure mirror pointer), not the local .branch.";
    };

    configuration = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "vm-cli-efi";
      description = "Flake attribute to build (nixosConfigurations.<name>). Must be set when enable is true — it intentionally differs from networking.hostName.";
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "1d";
      description = "How often to check for updates (systemd monotonic OnUnitInactiveSec — counted from the previous run's end, unlike GLF-OS OnUnitActiveSec which counts from its start). Daily checks absorb manual rev bumps (every 3-4 days) within a day; wall-clock drifting is intended — updates spread themselves.";
    };

    startDelay = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "Delay after boot before the first check (systemd OnBootSec). Short like GLF-OS (1min) so machines catch up promptly, with room for the desktop to settle (network-online.target orders anyway).";
    };

    randomizedDelay = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "RandomizedDelaySec for the update timer (spread a fleet).";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically reboot when the new generation changes kernel or init.";
    };

    notify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Desktop notification on success/failure. Only effective with a real DE installed and an active graphical session; otherwise journal-only (failures are queued for the next login).";
    };

    notifyIcon = lib.mkOption {
      type = lib.types.str;
      default = "nix-snowflake-white";
      description = "Icon name for desktop notifications (hicolor theme, shown with the title by the shell).";
    };

    notifyTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10000;
      description = "Notification display time in milliseconds (-t). Honored by most servers; GNOME caps custom timeouts (only critical persists).";
    };

    logFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/log/nixos-auto-update.log";
      description = "Persistent text log (journald stays the binary source of truth). Rotated by logrotate.";
    };

    minDiskGB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Minimum free space on /nix/store (GiB) to start an update run.";
    };

    timeouts = {
      lsRemote = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "Budget for resolving the channel revision (git ls-remote).";
      };

      fetch = lib.mkOption {
        type = lib.types.str;
        default = "10m";
        description = "Budget for the incremental channel force-sync (git fetch).";
      };

      clone = lib.mkOption {
        type = lib.types.str;
        default = "30m";
        description = "Budget for a fresh channel clone (fallback path).";
      };

      build = lib.mkOption {
        type = lib.types.str;
        default = "1h";
        description = "Budget for nixos-rebuild build.";
      };

      boot = lib.mkOption {
        type = lib.types.str;
        default = "1h";
        description = "Budget for nixos-rebuild boot / switch-to-configuration boot.";
      };

      internetWait = lib.mkOption {
        type = lib.types.ints.positive;
        default = 600;
        description = "How long to wait for internet connectivity (seconds) before giving up.";
      };
    };

    healthCheck = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Validate staged generations after boot (healthcheck service).";
      };

      units = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default =
          if config.marker.hostProfile == "desktop" then
            [ "display-manager.service" ]
          else
            [ "sshd.service" ];
        example = [
          "sshd.service"
          "NetworkManager.service"
        ];
        description = "Systemd units that must be active after a staged boot. Overridable per machine.";
      };

      requireNetwork = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Require a default IPv4 route after a staged boot.";
      };

      checkFailedUnits = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Fail validation when any unit is in failed state after a staged boot (essential-boot signal).";
      };

      autoRollback = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Restore the previous healthy system as next boot generation when a staged boot is unhealthy (one-shot per staged generation; the inhibit gate is kept regardless — a human must clear it). Off by default: manual rollback via the kept boot entries.";
      };

      timeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Per-check budget in seconds (service TimeoutStartSec adds a minute).";
      };
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Verbose logging and debug-labeled generations. When enabled, the auto-update service emits extra diagnostic output (transaction phases, state dumps, command details) and the generated system profile is labeled \"debug\" so debug-built generations are identifiable in `nix-env --list-generations` and `systemctl status`.";
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.configuration != null && cfg.configuration != "";
            message = "system.autoUpdate.configuration must be set to a nixosConfigurations attribute (e.g. \"vm-cli-efi\") when system.autoUpdate.enable is true.";
          }
        ];
      }

      (import ./services.nix {
        inherit
          lib
          pkgs
          config
          cfg
          repo
          ;
      })
    ]
  );
}
