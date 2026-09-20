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

  ### Shared PATH blocks (hand-picked bin dirs, output-aware). Small services
  ### only get what their assembled script text uses — see test-shell-paths.sh.
  pathCore = [
    "${pkgs.coreutils}/bin"
  ];
  pathRoot = pathCore ++ [
    "${pkgs.util-linux.bin}/bin"
    "${pkgs.libnotify}/bin"
  ];
  pathHealth = pathRoot ++ [
    "${config.systemd.package}/bin"
    "${pkgs.gnugrep}/bin"
  ];
  pathMain = pathHealth ++ [
    "${config.nix.package}/bin"
    "${config.system.build.nixos-rebuild}/bin"
    "${pkgs.gitMinimal}/bin"
    "${pkgs.diffutils}/bin"
    "${pkgs.curl}/bin"
    "${pkgs.gawk}/bin"
    "${pkgs.gnused}/bin"
    "${pkgs.nix-output-monitor}/bin"
    "${pkgs.nvd}/bin"
  ];
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
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];

      ### Bootloader writes must land on the mounted ESP, never on a
      ### stale /boot dir — order after it (harmless where /boot is no
      ### separate mount: requires the parent mount instead).
      RequiresMountsFor = [ "/boot" ];

      ### Laptops: never update on battery.
      ConditionACPower = true;
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
    };

    ### Explicit restrictive PATH (hand-picked bin dirs, output-aware):
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
      REBUILD_BUILD_TIMEOUT_ENABLED=1
      REBUILD_BOOT_TIMEOUT="${cfg.timeouts.boot}"
      DEBUG_MODE=${if cfg.debug then "1" else "0"}
      SYSTEM_PROFILE=/nix/var/nix/profiles/system
      FLAKE="${cfg.flakeRef}"
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

      ### --- source: local checkout when usable, remote ref otherwise ---
      ${lib.optionalString (cfg.localCheckout != null) ''
        CHECKOUT="${cfg.localCheckout}"
        ### safe.directory: the service runs as root on checkouts owned by
        ### regular users — without it git aborts with "dubious ownership".
        if [[ -d "$CHECKOUT/.git" ]]; then
          if git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" diff --quiet && [[ "$(git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" branch --show-current)" == "${cfg.channel}" ]]; then
            _status INFO "Pulling local checkout $CHECKOUT."
            if git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" pull --ff-only; then
              FLAKE="$CHECKOUT"
              SRC_ID=$(git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" rev-parse HEAD) || _fail state-error "checkout revision unreadable"
            else
              _status WARNING "Pull failed, falling back to remote ${cfg.flakeRef} ($(_err_lookup local-pull body_en))."
            fi
          else
            _status WARNING "Checkout dirty or not on ${cfg.channel}, using remote ${cfg.flakeRef}."
          fi
        else
          _status WARNING "No checkout at $CHECKOUT, using remote ${cfg.flakeRef}."
        fi
      ''}

      ### --- remote mode: force-sync the machine-owned mirror clone. ---
      ### Never force the human-owned localCheckout above (pull --ff-only
      ### + fallback); the mirror here is disposable cache, so fetch --force
      ### + reset --hard follows channel force-pushes (soak advances, phase
      ### jumps). Tags are unwanted update ballast: --no-tags everywhere.
      if [[ "$FLAKE" == "${cfg.flakeRef}" ]]; then
        _debug "Remote mode — syncing channel clone"
        _sync_channel_clone
      else
        _debug "Local checkout mode — $FLAKE"
      fi

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

      ${lib.optionalString cfg.updateInputs ''
        _status INFO "Updating inputs in $FLAKE."
        _update_flake_inputs
        LOCK_HASH=$(sha256sum "$FLAKE/flake.lock" | cut -d' ' -f1) || _fail flake-lock-missing "$FLAKE after update"
        if [[ -n "$last_ok" && "$last_ok" == "$SRC_ID $LOCK_HASH" ]]; then
          _status INFO "Inputs already current, skipping rebuild."
          exit 0
        fi
      ''}

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
          _notify_or_queue \
            "Mise à jour NixOS — Redémarrage" \
            "Nouveau noyau ou init, redémarrage automatique." \
            "NixOS Update — Rebooting" \
            "New kernel/init, automatic reboot." \
            "critical"
          systemctl reboot
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

  systemd.services.nixos-auto-update-notify-failure = {
    description = "Notify users when nixos-auto-update failed unexpectedly";

    serviceConfig = {
      Type = "oneshot";
      StateDirectory = stateDir;
    };

    environment = {
      AUTO_UPDATE_NOTIFY = if (cfg.notify && hasRealDesktop) then "1" else "0";
      PATH = lib.mkForce (lib.concatStringsSep ":" pathRoot);
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
      PATH = lib.mkForce (lib.concatStringsSep ":" (pathCore ++ [ "${pkgs.libnotify}/bin" ]));
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
