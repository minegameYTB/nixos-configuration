# configurations/modules/misc/auto-update/services.nix — systemd assembly
# for the auto-update services (GLF-OS services.nix style).
#
# Takes the resolved module config (cfg), repo info and toolchain handles,
# assembles the fragment scripts and declares: nixos-auto-update (+ the
# onFailure notify-failure unit), nixos-autoupdate-healthcheck, the per-user
# notify-pending unit, the timer and the logrotate rotation. default.nix
# keeps options + assertions and imports this file. Fragment contracts live
# in their own headers; each PATH block mirrors exactly what its assembled
# script uses (checked by test-shell-paths.sh).
{
  lib,
  pkgs,
  config,
  cfg,
  repo,
}:

let
  errors = import ./errors.nix { inherit lib; };
  errBash = errors.toBash { };
  output = import ./output.nix { };
  notifier = import ./notifier.nix {
    inherit (cfg) notifyIcon notifyTimeout;
  };
  transactionScript = import ./transaction.nix { };
  syncScript = import ./sync.nix { inherit cfg repo; };
  healthScript = import ./health.nix { inherit lib cfg; };
  debugScript = import ./debug.nix { inherit pkgs; };

  ### Single source for the service state dir (StateDirectory + scripts).
  stateDir = "nixos-auto-update";

  ### Real desktop = GNOME actually enabled, not just marker.hostProfile.
  ### Notifications are only attempted in that case (plus an active graphical
  ### session checked at runtime) — servers stay journal-only.
  hasRealDesktop = config.services.desktopManager.gnome.enable;

  ### Tight per-service envs: each service gets exactly one /bin with
  ### only the binaries it calls (see env.nix + test-shell-paths.sh).
  ### The host PATH is never inherited. Three tiers: core for the
  ### unprivileged pending service, health for the small root services
  ### (healthcheck + notify-failure), main for the updater itself.
  env = import ./env.nix { inherit pkgs config lib; };
  pathCore = [ "${env.core}/bin" ];
  pathHealth = [ "${env.health}/bin" ];
  pathMain = [ "${env.main}/bin" ];
in
{
  services.logrotate.settings.nixos-auto-update = {
    files = [ cfg.logFile ];
    frequency = "daily";
    rotate = 7;
    compress = false;
    copytruncate = true;
    missingok = true;
    notifempty = true;
  };

  systemd.services.nixos-auto-update = {
    description = "Automatic system update from channel ${cfg.channel}";

    unitConfig = {
      ### Network is mandatory (fetch channel + substituters).
      ### Order after nix-gc when both run: GC reclaims store space first
      ### (the disk-space precheck sees the real free space) and avoids
      ### GC/build I/O contention. Deliberately NOT in Wants: GC is weekly,
      ### updates are daily — pulling it in would GC on every run.
      After = [
        "network-online.target"
        "nix-gc.service"
      ];
      Wants = [ "network-online.target" ];

      ### Bootloader writes must land on the mounted ESP, never on a
      ### stale /boot dir — order after it (harmless where /boot is no
      ### separate mount: requires the parent mount instead).
      RequiresMountsFor = [ "/boot" ];

      ### Laptops: never update on battery unless requireACPower is
      ### disabled (transportables that are effectively always plugged in).
      ConditionACPower = lib.mkIf cfg.requireACPower true;
    };

    ### Detailed failures are delivered by the onFailure unit even when
    ### this service dies before notifying itself.
    onFailure = [ "nixos-auto-update-notify-failure.service" ];

    ### Low I/O + CPU priority: updates must never disturb the running system.
    ### NO mount-namespacing sandbox here (ProtectSystem/PrivateTmp/...):
    ### this service drives nix builds, and the nix sandbox needs its own
    ### user+mount namespaces — nesting it inside a systemd sandbox fails
    ### with "VFS: Mount too revealing" / "no kernel namespaces" (seen in
    ### prod). Confinement stays on: restrictive PATH + low priority +
    ### ConditionACPower. (Checked by test-shell-paths.sh: no sandbox keys.)
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
      StateDirectory = stateDir;
      ### A colliding run (manual start over a timer run) exits 75 and
      ### stays green instead of flagging the timer as failed.
      SuccessExitStatus = [ 75 ];
      ### Kill nix/nixos-rebuild children with the service on timeout.
      KillMode = "control-group";
      ### No start timeout: every phase is self-bounded via timeout(1)
      ### (fetch/clone/build/boot budgets, internet wait, GC-wait
      ### ExecStartPre, reboot countdown) — a manager default would kill
      ### long but healthy runs mid-flight.
      TimeoutStartSec = "infinity";
      ### Mirror of the nix-gc flock gate: After= cannot order against an
      ### already-active unit (same-transaction jobs only), so if a weekly
      ### GC is running when the timer fires, wait for it here (up to 2h,
      ### then fail the run). Fail-open when the unit is absent. Absolute
      ### paths: the restricted service PATH applies to ExecStartPre too.
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c 'for ((i=0; i<120; i++)); do ${config.systemd.package}/bin/systemctl is-active --quiet nix-gc.service || exit 0; ${pkgs.coreutils}/bin/sleep 60; done; exit 1'"
      ];
    };

    ### Explicit restrictive PATH (one package dir per entry, output-aware):
    ### only these directories exist for the script — nothing inherited
    ### and nothing from the host (/run/current-system is never used).
    environment = {
      AUTO_UPDATE_NOTIFY = if (cfg.notify && hasRealDesktop) then "1" else "0";
      PATH = lib.mkForce (lib.concatStringsSep ":" pathMain);
    };

    script = ''
      # >>>BEGIN main-flow
      set -euo pipefail
      WORKDIR=/var/lib/${stateDir}
      STATE_DIR="$WORKDIR"
      STATE_FILE="$WORKDIR/last-rebuild-status"
      LOG_FILE="${cfg.logFile}"
      LOCK_FILE=/run/lock/nixos-auto-update.lock
      TRANSACTION_ROOT="$WORKDIR/update-transactions"
      TRANSACTION_DIR="$TRANSACTION_ROOT/current"
      TRANSACTION_ACTIVE=0
      TRANSACTION_PRESERVE_ON_FAILURE=0
      TRANSACTION_RECOVERED=0
      TRANSACTION_AUTO_ROLLED_BACK=0
      BOOT_INSTALL_MAX_ATTEMPTS=3
      REBUILD_BOOT_TIMEOUT="${cfg.timeouts.boot}"
      DEBUG_MODE=${if cfg.debug then "1" else "0"}
      SYSTEM_PROFILE=/nix/var/nix/profiles/system
      FLAKE=""
      LAST_OK_FILE="$WORKDIR/last-ok"
      STAGED_FILE="$WORKDIR/staged-system"
      PREVIOUS_FILE="$WORKDIR/previous-system"
      INHIBITED_FILE="$WORKDIR/inhibited"
      NOTIFIED_FILE="$WORKDIR/notified-generation"
      SRC_ID=""
      LOCK_HASH=""

      ${errBash}
      ${output.full}
      ${notifier.full}
      ${transactionScript}
      ${syncScript}
      ${debugScript}

      ### Anti-spam state for note_once (see notifier.nix): each generation
      ### notifies at most once.
      last_notified=""

      _init_output
      _init_notifier
      NOTIFICATIONS_ENABLED="$AUTO_UPDATE_NOTIFY"
      _handle_debug_mode
      _debug "FLAKE=$FLAKE CONFIG=${cfg.configuration} DEBUG=$DEBUG_MODE NOTIFY=$AUTO_UPDATE_NOTIFY"

      last_notified=$(cat "$NOTIFIED_FILE" 2>/dev/null || true)
      last_ok=$(cat "$LAST_OK_FILE" 2>/dev/null || true)
      _debug "last_ok=$last_ok last_notified=$last_notified"

      ### Healthcheck inhibit: a failed post-boot validation blocks further
      ### auto-updates until a human clears $WORKDIR/inhibited explicitly.
      if [[ -f "$INHIBITED_FILE" ]]; then
        _debug "INHIBIT active: $(cat "$INHIBITED_FILE")"
        _status WARNING "auto-update inhibited ($(head -n1 "$INHIBITED_FILE"), clear $INHIBITED_FILE to resume)"
        exit 0
      fi
      _debug "No inhibit file, proceeding"

      _acquire_lock
      mkdir -p "$STATE_DIR"
      touch "$LOG_FILE" 2>/dev/null || true
      STATUS_LOGGING_ENABLED=1
      _install_transaction_traps
      _debug "Lock acquired, traps installed"

      if ! _write_state "running|$(date -Is)|update-interrupted|pending"; then
        rm -f -- "$STATE_FILE"
        _status ERROR "Unable to initialize the update state."
        exit 1
      fi

      _status INFO "===== NixOS update started at $(date -Is) ====="
      _debug "DEBUG_MODE=$DEBUG_MODE FLAKE=$FLAKE CONFIG=${cfg.configuration}"
      _debug "STAGED=$STAGED_FILE PREVIOUS=$PREVIOUS_FILE LAST_OK=$LAST_OK_FILE"
      _debug "TRANSACTION_ROOT=$TRANSACTION_ROOT"

      _begin_transaction

      if [[ "$TRANSACTION_AUTO_ROLLED_BACK" -eq 1 ]]; then
        _debug "AUTO_ROLLED_BACK=1, failing"
        _fail boot-recovery-rolled-back
      fi
      if [[ "$TRANSACTION_RECOVERED" -eq 1 ]]; then
        _debug "RECOVERED=1, recovery succeeded — notifying and exiting"
        _write_state "ok|$(date -Is)||none"
        _notify_or_queue \
          "Mise à jour NixOS — Reprise réussie" \
          "L’installation interrompue a été reprise avec succès. La nouvelle génération sera utilisée au prochain démarrage." \
          "NixOS Update — Recovery successful" \
          "The interrupted installation resumed successfully. The new generation will be used on the next boot." \
          "normal"
        exit 0
      fi

      _check_disk_space
      _wait_for_internet

      ### --- channel: force-sync the machine-owned mirror clone. ---
      ### The mirror is disposable cache, so fetch --force + reset --hard
      ### follows channel force-pushes (soak advances, phase jumps). Tags
      ### are unwanted update ballast: --no-tags everywhere.
      _debug "Syncing channel clone"
      _sync_channel_clone

      LOCK_HASH=$(sha256sum "$FLAKE/flake.lock" | cut -d' ' -f1) || _fail flake-lock-missing "$FLAKE"
      _debug "SRC_ID=$SRC_ID LOCK_HASH=$LOCK_HASH"

      ### Smart state: (source-id, lock-hash) of the last fully successful
      ### run. Identical state → nothing changed upstream: skip update AND
      ### rebuild (no network, no generation spam).
      if [[ -n "$last_ok" && "$last_ok" == "$SRC_ID $LOCK_HASH" ]]; then
        _debug "Unchanged since last run, skipping"
        _status INFO "Source and inputs unchanged since last successful run, skipping."
        exit 0
      fi
      _debug "Source or inputs changed, proceeding to rebuild"

      _status INFO "Rebuilding ${cfg.configuration} (boot, no immediate activation)."
      ### Store-resolved wrapper (system build handle, carries the repo's
      ### flake wrapper): no host dependency, and the explicit --flake
      ### bypasses its auto-injection.
      if ! _rebuild_system; then
        _fail rebuild-boot
      fi
      _commit_transaction

      NEW_SYSTEM=$(readlink -f /nix/var/nix/profiles/system)
      BOOTED_SYSTEM=$(readlink -f /run/booted-system)
      if [[ "$NEW_SYSTEM" == "$BOOTED_SYSTEM" ]]; then
        rm -f "$STAGED_FILE" "$PREVIOUS_FILE"
        echo "$SRC_ID $LOCK_HASH" > "$LAST_OK_FILE"
        note_once "$NEW_SYSTEM" \
          "Mise à jour NixOS — Déjà à jour" \
          "La génération en cours est la plus récente." \
          "NixOS Update — Already up to date" \
          "The running generation is current." \
          "normal"
        exit 0
      fi

      NEEDS_REBOOT=0
      for f in kernel init; do
        cmp -s "$BOOTED_SYSTEM/$f" "$NEW_SYSTEM/$f" || NEEDS_REBOOT=1
      done

      ### Record both ends for post-boot validation (healthcheck) BEFORE
      ### last-ok: a crash in between must leave last-ok behind (next run
      ### redoes everything, idempotently) — never ahead with staged files
      ### missing (next run would skip and the healthcheck would stay blind).
      ### Staged target first, then the healthy pre-update generation.
      echo "$BOOTED_SYSTEM" > "$PREVIOUS_FILE"
      echo "$NEW_SYSTEM" > "$STAGED_FILE"
      echo "$SRC_ID $LOCK_HASH" > "$LAST_OK_FILE"

      if (( NEEDS_REBOOT )); then
        if ${lib.boolToString cfg.allowReboot}; then
          # >>>BEGIN reboot-countdown
          _await_reboot_window() {
            # Countdown before an automatic reboot (allowReboot): sleeps
            # $1 minutes in 1-minute slices so a postponement marker ($2)
            # is honoured promptly. Returns 0 when the window expires
            # (reboot), 1 when postponed (marker consumed).
            local delay_min="$1" postpone_file="$2"
            local waited=0
            _status INFO "Automatic reboot in $delay_min min (touch $postpone_file to postpone)."
            while (( waited < delay_min )); do
              sleep 60
              waited=$((waited + 1))
              if [[ -f "$postpone_file" ]]; then
                rm -f -- "$postpone_file"
                return 1
              fi
            done
            return 0
          }
          # <<<END reboot-countdown
          REBOOT_POSTPONE_FILE="$WORKDIR/postpone-reboot"
          _notify_or_queue \
            "Mise à jour NixOS — Redémarrage dans ${toString cfg.rebootDelayMinutes} min" \
            "Nouveau noyau ou init. Redémarrage automatique dans ${toString cfg.rebootDelayMinutes} minutes — pour reporter : sudo touch $REBOOT_POSTPONE_FILE, puis redémarrez manuellement quand vous êtes prêt." \
            "NixOS Update — Rebooting in ${toString cfg.rebootDelayMinutes} min" \
            "New kernel/init. Automatic reboot in ${toString cfg.rebootDelayMinutes} minutes — to postpone: sudo touch $REBOOT_POSTPONE_FILE, then reboot manually when ready." \
            "critical"
          if _await_reboot_window ${toString cfg.rebootDelayMinutes} "$REBOOT_POSTPONE_FILE"; then
            _status WARNING "Reboot countdown expired, rebooting into the staged generation."
            _notify_or_queue \
              "Mise à jour NixOS — Redémarrage imminent" \
              "Le système redémarre maintenant sur la nouvelle génération." \
              "NixOS Update — Rebooting now" \
              "Rebooting into the new generation now." \
              "critical"
            systemctl reboot
          else
            _notify_or_queue \
              "Mise à jour NixOS — Redémarrage reporté" \
              "Le redémarrage automatique est annulé. Redémarrez manuellement pour activer la génération staged." \
              "NixOS Update — Reboot postponed" \
              "Automatic reboot cancelled. Reboot manually to activate the staged generation." \
              "normal"
          fi
        else
          note_once "$NEW_SYSTEM" \
            "Mise à jour NixOS — Redémarrage requis" \
            "Nouvelle génération staged, redémarrez pour l’activer." \
            "NixOS Update — Reboot required" \
            "New generation staged, reboot to activate." \
            "normal"
        fi
      else
        note_once "$NEW_SYSTEM" \
          "Mise à jour NixOS — Mise à jour staged" \
          "La nouvelle génération s’activera au prochain démarrage." \
          "NixOS Update — Update staged" \
          "New generation will activate on next boot." \
          "normal"
      fi
      # <<<END main-flow
    '';
  };

  ### Symmetric GC ordering: the main service waits for nix-gc via After=,
  ### and nix-gc waits for a running update here. flock on the update lock
  ### (held for the whole run, see _acquire_lock — instant no-op when idle).
  ### On timeout the GC fails instead of collecting mid-build (weekly retry);
  ### TimeoutStartSec must exceed the flock wait since ExecStartPre counts
  ### toward start timeout (stock default is 90s). Absolute flock path: the
  ### stock nix-gc unit has no restrictive PATH of ours. Scoped to
  ### autoUpdate-enabled machines like the rest of this file.
  systemd.services.nix-gc = {
    unitConfig.After = [ "nixos-auto-update.service" ];
    serviceConfig = {
      ExecStartPre = [
        "+${pkgs.util-linux.bin}/bin/flock -w 10800 /run/lock/nixos-auto-update.lock -c true"
      ];
      # Keep the stock oneshot default (disabled start timeout): only the
      # flock wait above is bounded (3h); a long GC run itself must never
      # be killed for our gating.
      TimeoutStartSec = "infinity";
    };
  };

  systemd.services.nixos-auto-update-notify-failure = {
    description = "Notify users when nixos-auto-update failed unexpectedly";

    serviceConfig = {
      Type = "oneshot";
      StateDirectory = stateDir;
    };

    environment = {
      AUTO_UPDATE_NOTIFY = if (cfg.notify && hasRealDesktop) then "1" else "0";
      PATH = lib.mkForce (lib.concatStringsSep ":" pathHealth);
    };

    script = ''
      # >>>BEGIN failure-flow
      set -euo pipefail
      STATE_DIR=/var/lib/${stateDir}
      STATE_FILE="$STATE_DIR/last-rebuild-status"
      LOG_FILE="${cfg.logFile}"

      ${errBash}
      ${output.core}
      ${notifier.full}

      _init_output
      _init_notifier
      NOTIFICATIONS_ENABLED="$AUTO_UPDATE_NOTIFY"

      _notify_failure
      # <<<END failure-flow
    '';
  };

  systemd.services.nixos-autoupdate-healthcheck = lib.mkIf cfg.healthCheck.enable {
    description = "Validate staged auto-update generation after boot";

    unitConfig = {
      After = lib.optional cfg.healthCheck.requireNetwork "network-online.target";
      Wants = lib.optional cfg.healthCheck.requireNetwork "network-online.target";
    };

    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = cfg.healthCheck.timeout + 60;
      StateDirectory = stateDir;
    };

    ### Explicit restrictive PATH (hand-picked bin dirs, output-aware).
    environment = {
      AUTO_UPDATE_NOTIFY = if (cfg.notify && hasRealDesktop) then "1" else "0";
      PATH = lib.mkForce (lib.concatStringsSep ":" pathHealth);
    };

    script = ''
      # >>>BEGIN health-flow
      set -euo pipefail
      WORKDIR=/var/lib/${stateDir}
      STATE_DIR="$WORKDIR"
      STATE_FILE="$WORKDIR/last-rebuild-status"
      LOG_FILE="${cfg.logFile}"
      STAGED_FILE="$WORKDIR/staged-system"
      PREVIOUS_FILE="$WORKDIR/previous-system"
      INHIBITED_FILE="$WORKDIR/inhibited"
      ROLLED_BACK_FILE="$WORKDIR/rolled-back"
      REBUILD_BOOT_TIMEOUT="${cfg.timeouts.boot}"

      ${errBash}
      ${output.core}
      ${notifier.full}
      ${transactionScript}
      ${healthScript}

      _init_output
      _init_notifier
      NOTIFICATIONS_ENABLED="$AUTO_UPDATE_NOTIFY"
      STATUS_LOGGING_ENABLED=1

      _validate_staged_boot
      # <<<END health-flow
    '';
  };

  ### Deferred delivery: shows the queued notification at next graphical
  ### login (the root services can only queue when headless). Runs unprivileged.
  systemd.user.services.nixos-auto-update-notify-pending = {
    description = "Deliver a pending NixOS update notification";
    wantedBy = [ "graphical-session.target" ];
    unitConfig = {
      StartLimitIntervalSec = 360;
      StartLimitBurst = 30;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "nixos-auto-update-notify-pending" ''
        set -euo pipefail
        STATE_DIR=/var/lib/${stateDir}
        ${notifier.user}
        _init_notifier
        _deliver_pending_notification
      '';
      Restart = "on-failure";
      RestartSec = "10s";
    };
    environment = {
      PATH = lib.mkForce (lib.concatStringsSep ":" pathCore);
    };
  };

  systemd.timers.nixos-auto-update = {
    description = "Timer for automatic system updates";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = cfg.startDelay;
      OnUnitInactiveSec = cfg.checkInterval;
      RandomizedDelaySec = cfg.randomizedDelay;
      Persistent = true;
      Unit = "nixos-auto-update.service";
    };
  };
}
