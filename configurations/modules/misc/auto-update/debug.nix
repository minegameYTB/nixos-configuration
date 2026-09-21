# configurations/modules/misc/auto-update/debug.nix — debug mode.
#
# When system.autoUpdate.debug = true, DEBUG_MODE=1 is set in the service
# environment:
#
# 1. Verbose logging: _debug calls emit [DEBUG] lines to journal + log file
#    at every significant decision point in the service flow.
#
# 2. Dry-run gate: on service start, _handle_debug_mode runs the safe local
#    checks (dependencies + transaction tests in isolated temp dirs, no
#    /nix/store write, no network, no nixos-rebuild) and proceeds with the
#    actual update if all checks pass. Exits early on check failure.
#
# Callers must set before use: DEBUG_MODE, LOG_FILE, STATE_DIR,
# TRANSACTION_ROOT/DIR, SYSTEM_PROFILE.
{ pkgs }:

''
  # >>>BEGIN debug
  # ─── verbose logging ──────────────────────────────────────────────────
  _debug() {
    [ "$DEBUG_MODE" -eq 1 ] || return 0
    ${pkgs.coreutils}/bin/printf '[DEBUG] %s\n' "$*" >> "$LOG_FILE" 2>/dev/null || true
    ${pkgs.coreutils}/bin/printf '[DEBUG] %s\n' "$*" >&5
  }

  # ─── dry-run test helpers ─────────────────────────────────────────────
  _debug_info() { ${pkgs.coreutils}/bin/printf '[DEBUG] %s\n' "$*"; }
  _debug_pass() { ${pkgs.coreutils}/bin/printf '[PASS] %s\n' "$*"; }
  _debug_fail() {
    ${pkgs.coreutils}/bin/printf '[FAIL] %s\n' "$*" >&2
    debug_failures=$((debug_failures + 1))
  }

  _run_debug_dependency_checks() {
    local command_name
    for command_name in curl git nix nixos-rebuild nvd timeout; do
      if command -v "$command_name" >/dev/null 2>&1; then
        _debug_pass "Dependency available: $command_name"
      else
        _debug_fail "Missing dependency: $command_name"
      fi
    done
  }

  _run_debug_transaction_tests() {
    local debug_root
    local saved_state_dir="$STATE_DIR"
    local saved_state_file="$STATE_FILE"
    local saved_system_profile="$SYSTEM_PROFILE"
    local saved_transaction_root="$TRANSACTION_ROOT"
    local saved_transaction_dir="$TRANSACTION_DIR"
    local old_system new_system

    debug_root=$(${pkgs.coreutils}/bin/mktemp -d /tmp/nixos-auto-update-debug.XXXXXX)
    STATE_DIR="$debug_root/state"
    STATE_FILE="$STATE_DIR/last-rebuild-status"
    TRANSACTION_ROOT="$STATE_DIR/update-transactions"
    TRANSACTION_DIR="$TRANSACTION_ROOT/current"
    SYSTEM_PROFILE="$debug_root/system-profile"
    TRANSACTION_ACTIVE=0
    TRANSACTION_PRESERVE_ON_FAILURE=0
    TRANSACTION_RECOVERED=0
    TRANSACTION_AUTO_ROLLED_BACK=0
    old_system="$debug_root/system-old"
    new_system="$debug_root/system-new"

    ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR" "$old_system/bin" "$new_system"
    ${pkgs.coreutils}/bin/ln -s "$old_system" "$SYSTEM_PROFILE"
    ${pkgs.coreutils}/bin/printf '%s\n' \
      '#!/bin/sh' \
      "${pkgs.coreutils}/bin/ln -sfn '$old_system' '$SYSTEM_PROFILE'" \
      > "$old_system/bin/switch-to-configuration"
    ${pkgs.coreutils}/bin/chmod +x "$old_system/bin/switch-to-configuration"

    # begin → rollback: transaction dir removed.
    _begin_transaction
    _set_transaction_phase "applying"
    _rollback_transaction
    if [ ! -d "$TRANSACTION_DIR" ]; then
      _debug_pass "Rollback removes the transaction dir."
    else
      _debug_fail "Rollback left the transaction dir behind."
    fi

    # begin → commit: phase committed, dir removed.
    _begin_transaction
    _set_transaction_phase "applying"
    _commit_transaction
    if [ ! -d "$TRANSACTION_DIR" ]; then
      _debug_pass "Commit cleans up the transaction dir."
    else
      _debug_fail "Commit left the transaction dir behind."
    fi

    # begin → interrupt (prepared) → recover: rolls back.
    _begin_transaction
    TRANSACTION_ACTIVE=0
    _recover_transaction
    if [ ! -d "$TRANSACTION_DIR" ]; then
      _debug_pass "Interrupted prepared transaction is recovered (rolled back)."
    else
      _debug_fail "Interrupted prepared transaction was not recovered."
    fi

    # begin → applying, no profile change → recover rolls back.
    _begin_transaction
    _set_transaction_phase "applying"
    TRANSACTION_ACTIVE=0
    _recover_transaction
    if [ ! -d "$TRANSACTION_DIR" ]; then
      _debug_pass "Applying transaction without profile change rolls back on recovery."
    else
      _debug_fail "Applying recovery did not roll back with unchanged profile."
    fi

    # Signal during applying → preserve, not rollback.
    _begin_transaction
    _set_transaction_phase "applying"
    TRANSACTION_PRESERVE_ON_FAILURE=0
    _preserve_transaction_during_interruption
    _rollback_transaction
    if [ -d "$TRANSACTION_DIR" ]; then
      _debug_pass "Signal during boot installation preserves the transaction."
    else
      _debug_fail "Signal handling rolled back a transaction that must be preserved."
    fi

    # Clean up the preserved transaction before the next test so _begin_transaction
    # does not trip over a leftover dir (PRESERVE_ON_FAILURE is still 1 here).
    TRANSACTION_ACTIVE=0
    TRANSACTION_PRESERVE_ON_FAILURE=0
    rm -rf -- "$TRANSACTION_DIR"

    # Profile advanced + failing boot install → attempt counter grows.
    _begin_transaction
    _set_transaction_phase "applying"
    ${pkgs.coreutils}/bin/ln -sfn "$new_system" "$SYSTEM_PROFILE"
    _write_boot_install_attempts 1
    TRANSACTION_ACTIVE=0
    if (
      _install_boot_configuration() { return 1; }
      _recover_transaction
    ); then
      _debug_fail "Recovery unexpectedly succeeded with a failing boot install."
    elif [ -d "$TRANSACTION_DIR" ] \
      && [ "$(${pkgs.coreutils}/bin/cat "$TRANSACTION_DIR/boot-install-attempts")" -eq 2 ]; then
      _debug_pass "Failed boot retry persists the attempt counter."
    else
      _debug_fail "Failed boot retry did not persist the attempt counter."
    fi

    # Profile advanced + successful boot install → commit.
    TRANSACTION_ACTIVE=0
    TRANSACTION_RECOVERED=0
    if (
      _install_boot_configuration() { return 0; }
      _recover_transaction
    ) && [ ! -d "$TRANSACTION_DIR" ]; then
      _debug_pass "Successful boot retry commits the preserved transaction."
    else
      _debug_fail "Successful boot retry did not commit the transaction."
    fi

    # Restore globals.
    TRANSACTION_ACTIVE=0
    TRANSACTION_PRESERVE_ON_FAILURE=0
    TRANSACTION_RECOVERED=0
    TRANSACTION_AUTO_ROLLED_BACK=0
    STATE_DIR="$saved_state_dir"
    STATE_FILE="$saved_state_file"
    SYSTEM_PROFILE="$saved_system_profile"
    TRANSACTION_ROOT="$saved_transaction_root"
    TRANSACTION_DIR="$saved_transaction_dir"
    ${pkgs.coreutils}/bin/rm -rf -- "$debug_root"
  }

  _handle_debug_mode() {
    [ "$DEBUG_MODE" -eq 1 ] || return 0
    trap - ERR HUP INT TERM EXIT
    local debug_failures=0
    _debug_info "Dry-run: dependency checks + transaction tests (no store write, no network)."
    _run_debug_dependency_checks
    _run_debug_transaction_tests
    if [ "$debug_failures" -ne 0 ]; then
      _debug_info "$debug_failures check(s) failed." >&2
      exit 1
    fi
    _debug_info "All dry-run checks passed, proceeding with verbose update."
  }
  # <<<END debug
''
