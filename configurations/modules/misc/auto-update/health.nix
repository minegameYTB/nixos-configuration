# configurations/modules/misc/auto-update/health.nix — post-boot validation
# of a staged generation (the `validating` phase of the transaction).
#
# Contract (functions exported):
#   check_health                — 0 iff required units active + default IPv4
#                                 route present (when required) + no failed
#                                 units (when checked). Pure: only _status.
#   _validate_staged_boot       — compare $BOOTED vs $STAGED_FILE: silent exit
#                                 when nothing staged; on unhealthy staged boot
#                                 write $INHIBITED_FILE + notify critical via
#                                 _fail-style state, and when
#                                 cfg.healthCheck.autoRollback is true restore
#                                 $PREVIOUS_FILE as next boot generation
#                                 (one-shot guard $ROLLED_BACK_FILE).
#
# Callers must set before use: STAGED_FILE, INHIBITED_FILE, PREVIOUS_FILE,
# ROLLED_BACK_FILE, STATE_DIR/FILE, LOG_FILE, REBUILD_BOOT_TIMEOUT,
# NOTIFICATIONS_ENABLED. Uses _write_state (output.nix), _notify_or_queue
# (notifier.nix), _switch_boot_to_system (transaction.nix), _err_lookup
# (errors.nix).
{ lib, cfg }:

''
  # >>>BEGIN health
  check_health() {
    local u bad=0 route_ok=0 iface dest gw
    for u in ${lib.escapeShellArgs cfg.healthCheck.units}; do
      systemctl is-active --quiet "$u" || { _status WARNING "unhealthy unit: $u"; bad=1; }
    done
    if ${lib.boolToString cfg.healthCheck.requireNetwork}; then
      # Default route via a gateway (lo excluded: destination 00000000
      # with a 00000000 gateway is just loopback, not uplink).
      while read -r iface dest gw _; do
        if [[ "$iface" != "lo" && "$dest" == "00000000" && "$gw" != "00000000" ]]; then
          route_ok=1
          break
        fi
      done < "''${PROC_NET_ROUTE:-/proc/net/route}" 2>/dev/null || true
      if (( ! route_ok )); then
        _status WARNING "no default IPv4 route"
        bad=1
      fi
    fi
    # Essential-boot signal: any failed unit fails validation.
    # (Fail-open on tool error: systemctl itself failing will usually
    # trip the unit checks above anyway.)
    if ${lib.boolToString cfg.healthCheck.checkFailedUnits}; then
      if systemctl list-units --state=failed --no-legend --no-pager 2>/dev/null | grep -q .; then
        _status WARNING "failed units present"
        bad=1
      fi
    fi
    return $bad
  }

  _validate_staged_boot() {
    local booted staged previous
    local urgency title_fr body_fr title_en body_en

    booted=$(readlink -f "''${AUTO_UPDATE_BOOTED_SYSTEM:-/run/booted-system}")
    if [ ! -f "$STAGED_FILE" ]; then
      _status INFO "No staged generation, nothing to validate."
      return 0
    fi
    staged=$(cat "$STAGED_FILE")
    if [ "$staged" != "$booted" ]; then
      _status INFO "Booted $booted is not the staged $staged, nothing to validate."
      return 0
    fi

    _status INFO "Validating staged generation $staged."
    if check_health; then
      rm -f "$STAGED_FILE" "$INHIBITED_FILE" "$PREVIOUS_FILE" "$ROLLED_BACK_FILE"
      _status INFO "Staged generation healthy, adopted."
      return 0
    fi

    {
      echo "auto-update inhibited: unhealthy staged boot"
      echo "date: $(date -u +%FT%TZ)"
      echo "booted: $booted"
    } > "$INHIBITED_FILE"
    if ! _write_state "failed|$(date -Is)|healthcheck-failed|pending"; then
      rm -f -- "$STATE_FILE"
      _status ERROR "Unable to persist the healthcheck failure state."
    fi

    urgency=$(_err_lookup healthcheck-failed urgency)
    title_fr=$(_err_lookup healthcheck-failed title_fr)
    body_fr=$(_err_lookup healthcheck-failed body_fr)
    title_en=$(_err_lookup healthcheck-failed title_en)
    body_en=$(_err_lookup healthcheck-failed body_en)

    if ${lib.boolToString cfg.healthCheck.autoRollback}; then
      previous=$(cat "$PREVIOUS_FILE" 2>/dev/null || true)
      if [ -n "$previous" ] && [ "$previous" != "$booted" ] && [ ! -f "$ROLLED_BACK_FILE" ]; then
        _status WARNING "Restoring previous healthy system $previous as next boot generation."
        if _switch_boot_to_system "$previous"; then
          date -u +%FT%TZ > "$ROLLED_BACK_FILE"
          urgency=$(_err_lookup boot-recovery-rolled-back urgency)
          title_fr=$(_err_lookup boot-recovery-rolled-back title_fr)
          body_fr=$(_err_lookup boot-recovery-rolled-back body_fr)
          title_en=$(_err_lookup boot-recovery-rolled-back title_en)
          body_en=$(_err_lookup boot-recovery-rolled-back body_en)
          if ${lib.boolToString cfg.allowReboot}; then
            _notify_or_queue "$title_fr" "$body_fr" "$title_en" "$body_en" "$urgency"
            _status WARNING "Automatic reboot into the restored healthy system."
            systemctl reboot
            return 1
          fi
          # The machine still runs the unhealthy system until someone
          # reboots: say so explicitly (catalogue bodies stay reboot-neutral).
          body_fr="$body_fr Redémarrez pour retrouver le système sain."
          body_en="$body_en Reboot to return to the healthy system."
        else
          _status ERROR "Automatic rollback failed; manual rollback required."
        fi
      elif [ -f "$ROLLED_BACK_FILE" ]; then
        _status WARNING "Rollback already performed for this staged generation; waiting for manual action."
      else
        _status WARNING "No healthy previous system recorded; manual rollback required."
      fi
    fi

    _notify_or_queue "$title_fr" "$body_fr" "$title_en" "$body_en" "$urgency"
    return 1
  }
  # <<<END health
''
