# configurations/modules/misc/auto-update/transaction.nix — update-time
# transaction state machine (GLF-OS style, adapted).
#
# Contract (functions exported):
#   _fail CODE [DETAIL]            — central failure point: ERROR log, rollback,
#                                    structured STATE_FILE
#                                    (failed|<date>|<code>|pending|notified),
#                                    bilingual critical notify, exit 1
#   _acquire_lock                  — flock --nonblock on $LOCK_FILE; holder
#                                    collision exits 75 (SuccessExitStatus)
#   _release_lock / _cleanup       — EXIT trap: rollback unless committed
#   _install_transaction_traps     — ERR/HUP/INT/TERM/EXIT wiring
#   _begin_transaction             — record old-system, phase=prepared
#   _set_transaction_phase PHASE / _commit_transaction
#   _boot_install_attempts / _write_boot_install_attempts /
#     _boot_install_attempts_exhausted
#   _transaction_profile_advanced  — 0 iff $SYSTEM_PROFILE moved since begin
#   _preserve_transaction_for_recovery [MSG] / _preserve_transaction_during_interruption
#   _restore_previous_system / _finish_previous_system_restoration
#   _recover_transaction           — resume/rollback logic at every run start
#   _rollback_transaction [PHASE]  — drop the unfinished transaction
#
# Callers must set before use: WORKDIR, STATE_DIR, STATE_FILE, LOG_FILE,
# LOCK_FILE, TRANSACTION_ROOT/DIR (+ ACTIVE/PRESERVE/RECOVERED/ROLLED_BACK
# flags, SYSTEM_PROFILE). Heavy network/build steps live in sync.nix.
{ }:

''
  # >>>BEGIN transaction
  _fail() {
    trap - ERR
    local reason="''${1:-unknown}"
    local detail="''${2:-}"
    local urgency title_fr body_fr title_en body_en terminal_body
    local failed_at

    urgency=$(_err_lookup "$reason" urgency)
    title_fr=$(_err_lookup "$reason" title_fr)
    body_fr=$(_err_lookup "$reason" body_fr)
    title_en=$(_err_lookup "$reason" title_en)
    body_en=$(_err_lookup "$reason" body_en)
    [ -n "$urgency" ] || urgency="critical"
    [ -n "$title_en" ] || {
      title_fr="Mise à jour NixOS — Échec"
      body_fr="La mise à jour NixOS a échoué ($reason). Voir $LOG_FILE."
      title_en="NixOS Update — Failure"
      body_en="The NixOS update failed ($reason). See $LOG_FILE."
    }
    case "''${LANG:-en}" in
      fr*) terminal_body="$body_fr" ;;
      *) terminal_body="$body_en" ;;
    esac
    [ -n "$detail" ] && terminal_body="$terminal_body ($detail)"
    _status ERROR "===== NixOS update failed at $(date -Is) ($reason) ====="
    _status ERROR "$terminal_body"
    _rollback_transaction || true
    failed_at=$(date -Is)
    if ! _write_state "failed|$failed_at|$reason|pending"; then
      rm -f -- "$STATE_FILE"
      _status ERROR "Unable to persist the update failure state."
    fi
    if [ "$NOTIFICATIONS_ENABLED" -eq 1 ] \
      && _notify_or_queue \
        "$title_fr" "$body_fr" "$title_en" "$body_en" "$urgency"; then
      _write_state "failed|$failed_at|$reason|notified" || \
        _status WARNING "Unable to record that the failure notification was sent."
    fi
    exit 1
  }

  _acquire_lock() {
    exec 9>"$LOCK_FILE"
    if ! flock --nonblock 9; then
      _status WARNING "Another nixos-auto-update process is already running."
      exit 75
    fi
  }

  _release_lock() {
    flock --unlock 9 2>/dev/null || true
    exec 9>&-
  }

  _set_transaction_phase() {
    local phase="$1"
    local phase_tmp="$TRANSACTION_DIR/.phase.new"

    printf '%s\n' "$phase" > "$phase_tmp"
    sync -f "$phase_tmp"
    mv -f "$phase_tmp" "$TRANSACTION_DIR/phase"
    sync -f "$TRANSACTION_DIR"
  }

  _write_boot_install_attempts() {
    local attempts="$1"
    local attempts_tmp="$TRANSACTION_DIR/.boot-install-attempts.new"

    printf '%s\n' "$attempts" > "$attempts_tmp"
    sync -f "$attempts_tmp"
    mv -f "$attempts_tmp" "$TRANSACTION_DIR/boot-install-attempts"
    sync -f "$TRANSACTION_DIR"
  }

  _boot_install_attempts() {
    local attempts

    # Transactions predating the counter necessarily already survived the
    # initial failure that left them in phase applying.
    if [ ! -f "$TRANSACTION_DIR/boot-install-attempts" ]; then
      printf '1\n'
      return 0
    fi

    attempts=$(cat "$TRANSACTION_DIR/boot-install-attempts")
    case "$attempts" in
      ""|*[!0-9]*)
        _status ERROR "Invalid boot installation attempt counter; selecting automatic rollback."
        printf '%s\n' "$BOOT_INSTALL_MAX_ATTEMPTS"
        ;;
      *)
        printf '%s\n' "$attempts"
        ;;
    esac
  }

  _boot_install_attempts_exhausted() {
    local attempts

    attempts=$(_boot_install_attempts)
    [ "$attempts" -ge "$BOOT_INSTALL_MAX_ATTEMPTS" ]
  }

  _transaction_profile_advanced() {
    local current_system=""
    local old_system=""

    [ -f "$TRANSACTION_DIR/old-system" ] && old_system=$(cat "$TRANSACTION_DIR/old-system")
    current_system=$(readlink -f "$SYSTEM_PROFILE" 2>/dev/null || true)
    [ -n "$old_system" ] \
      && [ -n "$current_system" ] \
      && [ "$current_system" != "$old_system" ]
  }

  _preserve_transaction_for_recovery() {
    TRANSACTION_PRESERVE_ON_FAILURE=1
    _status WARNING "''${1:-The system profile advanced before boot installation completed; preserving the transaction for retry.}"
  }

  _preserve_transaction_during_interruption() {
    local phase="unknown"

    [ "$TRANSACTION_ACTIVE" -eq 1 ] || return 0
    [ -f "$TRANSACTION_DIR/phase" ] && phase=$(cat "$TRANSACTION_DIR/phase")
    case "$phase" in
      applying|restoring-system|restoring-configuration)
        _preserve_transaction_for_recovery \
          "Interruption during phase '$phase'; preserving the transaction for automatic recovery."
        ;;
    esac
  }

  _rollback_transaction() {
    local rollback_phase="''${1:-rolling-back}"

    [ "$TRANSACTION_ACTIVE" -eq 1 ] || return 0

    if [ "$TRANSACTION_PRESERVE_ON_FAILURE" -eq 1 ]; then
      _status WARNING "Preserving the transaction for automatic recovery on the next run."
      TRANSACTION_ACTIVE=0
      return 0
    fi

    # This updater never mutates local checkouts: the only in-place state is
    # the transaction tracking itself (phase/old-system/attempts). Rolling
    # back drops it; a leftover flake.new clone is removed as well.
    _status WARNING "Rolling back the unfinished update transaction..."
    _set_transaction_phase "$rollback_phase" || true
    rm -rf -- "$TRANSACTION_DIR" "$WORKDIR/flake.new"
    sync -f "$TRANSACTION_ROOT" || true
    TRANSACTION_ACTIVE=0
    _status INFO "Update transaction rolled back."
  }

  _finish_previous_system_restoration() {
    TRANSACTION_PRESERVE_ON_FAILURE=0
    if ! _rollback_transaction "restoring-configuration"; then
      _preserve_transaction_for_recovery \
        "The previous system was restored, but cleanup is incomplete; it will resume on the next run."
      return 1
    fi
    TRANSACTION_AUTO_ROLLED_BACK=1
    _status WARNING "The previous system was restored automatically."
  }

  _switch_boot_to_system() {
    # Shared primitive: point the boot loader at an already-built system
    # generation. Used by update-time recovery (previous system) and by
    # post-boot rollback (previous-system file). Caller notifies.
    local target="$1"

    [ -n "$target" ] && [ -x "$target/bin/switch-to-configuration" ] || return 1
    timeout \
      --signal=TERM \
      --kill-after=1m \
      "$REBUILD_BOOT_TIMEOUT" \
      "$target/bin/switch-to-configuration" boot
  }

  _restore_previous_system() {
    local old_system=""

    [ -f "$TRANSACTION_DIR/old-system" ] && old_system=$(cat "$TRANSACTION_DIR/old-system")
    if [ -z "$old_system" ] || [ ! -x "$old_system/bin/switch-to-configuration" ]; then
      _status ERROR "The previous system generation is unavailable; automatic restoration cannot continue."
      _preserve_transaction_for_recovery \
        "Preserving the transaction until the previous system generation becomes available."
      return 1
    fi

    _status WARNING "Restoring the previous system automatically as the next boot generation."
    _set_transaction_phase "restoring-system"
    if ! _switch_boot_to_system "$old_system"; then
      _status ERROR "Unable to reinstall the previous system as the next boot generation."
      _preserve_transaction_for_recovery \
        "Preserving the transaction so automatic system restoration can retry on the next run."
      return 1
    fi

    _finish_previous_system_restoration
  }

  _attempt_boot_installation() {
    local attempts

    attempts=$(_boot_install_attempts)
    if [ "$attempts" -ge "$BOOT_INSTALL_MAX_ATTEMPTS" ]; then
      return 1
    fi
    attempts=$((attempts + 1))
    _write_boot_install_attempts "$attempts"
    _status INFO "Boot installation attempt $attempts/$BOOT_INSTALL_MAX_ATTEMPTS."
    _install_boot_configuration
  }

  _recover_transaction() {
    local attempts
    local phase="unknown"

    [ -d "$TRANSACTION_DIR" ] || return 0

    TRANSACTION_ACTIVE=1
    [ -f "$TRANSACTION_DIR/phase" ] && phase=$(cat "$TRANSACTION_DIR/phase")

    if [ "$phase" = "committed" ]; then
      _status INFO "Cleaning up a previously committed transaction."
      TRANSACTION_ACTIVE=0
      rm -rf -- "$TRANSACTION_DIR"
      return 0
    fi

    if [ "$phase" = "restoring-system" ]; then
      _status WARNING "Resuming automatic restoration of the previous system."
      _restore_previous_system
      return $?
    fi

    if [ "$phase" = "restoring-configuration" ]; then
      _status WARNING "Resuming restoration of the previous configuration."
      _finish_previous_system_restoration
      return $?
    fi

    if [ "$phase" = "applying" ]; then
      if _transaction_profile_advanced; then
        if _boot_install_attempts_exhausted; then
          _status WARNING "Boot installation failed $BOOT_INSTALL_MAX_ATTEMPTS times."
          _restore_previous_system
          return $?
        fi
        _status WARNING "The system profile advanced during the interrupted transaction; retrying boot installation."
        if _attempt_boot_installation; then
          _commit_transaction
          TRANSACTION_RECOVERED=1
          _status INFO "Interrupted boot installation recovered successfully."
          return 0
        fi
        if _boot_install_attempts_exhausted; then
          _status WARNING "Boot installation failed $BOOT_INSTALL_MAX_ATTEMPTS times."
          _restore_previous_system
          return $?
        fi
        _preserve_transaction_for_recovery
        return 1
      fi

      attempts=$(_boot_install_attempts)
      if [ "$attempts" -gt 0 ]; then
        _status WARNING "Boot installation was interrupted before the system profile advanced; reinstalling the previous boot generation."
        _restore_previous_system
        return $?
      fi
    fi

    _status WARNING "Recovering transaction left in phase '$phase'."
    _rollback_transaction
  }

  _begin_transaction() {
    local transaction_tmp

    mkdir -p "$TRANSACTION_ROOT"
    _recover_transaction
    TRANSACTION_PRESERVE_ON_FAILURE=0

    transaction_tmp=$(mktemp -d "$TRANSACTION_ROOT/.current.XXXXXX")

    readlink -f "$SYSTEM_PROFILE" > "$transaction_tmp/old-system" 2>/dev/null || true
    printf '0\n' > "$transaction_tmp/boot-install-attempts"
    printf 'prepared\n' > "$transaction_tmp/phase"
    sync -f "$transaction_tmp"
    mv -T -- "$transaction_tmp" "$TRANSACTION_DIR"
    sync -f "$TRANSACTION_ROOT"
    TRANSACTION_ACTIVE=1
    _status INFO "Update transaction prepared."
  }

  _commit_transaction() {
    [ "$TRANSACTION_ACTIVE" -eq 1 ] || return 0
    _set_transaction_phase "committed"
    TRANSACTION_ACTIVE=0
    TRANSACTION_PRESERVE_ON_FAILURE=0
    if ! rm -rf -- "$TRANSACTION_DIR"; then
      _status WARNING "The committed transaction will be cleaned up on the next run."
    fi
    sync -f "$TRANSACTION_ROOT" || true
  }

  _cleanup() {
    local exit_status="$1"

    trap - EXIT
    _rollback_transaction || true

    if [ "$DEBUG_MODE" -eq 0 ]; then
      _release_lock
    fi

    exit "$exit_status"
  }

  _handle_transaction_signal() {
    local signal="$1"

    trap - HUP INT TERM
    _status WARNING "Received $signal; stopping the update safely."
    _preserve_transaction_during_interruption
    _fail boot-recovery
  }

  _install_transaction_traps() {
    trap '_fail boot-recovery' ERR
    trap '_handle_transaction_signal HUP' HUP
    trap '_handle_transaction_signal INT' INT
    trap '_handle_transaction_signal TERM' TERM
    trap '_cleanup "$?"' EXIT
  }
  # <<<END transaction
''
