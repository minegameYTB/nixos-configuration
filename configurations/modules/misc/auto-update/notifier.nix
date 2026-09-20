# configurations/modules/misc/auto-update/notifier.nix — immediate and
# deferred desktop notifications for the auto-update services.
#
# Split (PATH-hygiene: the per-user pending service runs with coreutils +
# libnotify only):
#   user — _init_notifier, _queue_pending_notification,
#          _deliver_pending_notification (coreutils + libnotify only)
#   full — user + _notify_user, _notify_all_users, _notify,
#          _notify_or_queue, _notify_failure (adds util-linux runuser)
#
# The /run/user scan honors $AUTO_UPDATE_RUN_USER_DIR (tests point it at a
# fake tree; production leaves it unset).
#
# Callers must set before use: STATE_DIR, STATE_FILE, LOG_FILE,
# NOTIFICATIONS_ENABLED (1 in root services when AUTO_UPDATE_NOTIFY=1).
{ notifyIcon, notifyTimeout }:

let
  user = ''
    # >>>BEGIN notifier-user
    _init_notifier() {
      PENDING_NOTIFICATION_FILE="$STATE_DIR/pending-notification"
      NOTIFICATIONS_ENABLED=0
      # Budget per notify-send attempt (human time); the -t display timeout
      # below stays the user-facing notifyTimeout in milliseconds.
      NOTIFICATION_TIMEOUT=15s
    }

    _queue_pending_notification() {
      local urgency="''${5:-normal}"
      local notification_tmp
      local notification_id

      mkdir -p "$STATE_DIR"
      notification_tmp=$(mktemp "$STATE_DIR/.pending-notification.XXXXXX")
      notification_id="$(date +%s%N)-$$"
      printf '%s|%s|%s|%s|%s|%s\n' \
        "$notification_id" \
        "$urgency" \
        "$(printf '%s' "$1" | base64 -w 0)" \
        "$(printf '%s' "$2" | base64 -w 0)" \
        "$(printf '%s' "$3" | base64 -w 0)" \
        "$(printf '%s' "$4" | base64 -w 0)" \
        > "$notification_tmp"
      chmod 0644 "$notification_tmp"
      mv -f -- "$notification_tmp" "$PENDING_NOTIFICATION_FILE"
      sync -f "$STATE_DIR" || true
    }

    _deliver_pending_notification() {
      local notification_id=""
      local urgency=""
      local title_fr=""
      local message_fr=""
      local title_en=""
      local message_en=""
      local notification_state_dir
      local notification_marker
      local notification_marker_tmp
    local previous_notification_id=""
    local title
    local message
    local event_epoch event_age event_date
    event_epoch=""
    event_age=0
    event_date=""

      [ -r "$PENDING_NOTIFICATION_FILE" ] || return 0
      IFS='|' read -r notification_id urgency title_fr message_fr title_en message_en < "$PENDING_NOTIFICATION_FILE" || return 0
      [ -n "$notification_id" ] || return 0

      notification_state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-auto-update"
      notification_marker="$notification_state_dir/last-notification"
      if [ -r "$notification_marker" ]; then
        previous_notification_id=$(cat "$notification_marker" 2>/dev/null || true)
      fi
      [ "$previous_notification_id" != "$notification_id" ] || return 0

      case "$urgency" in
        low|normal|critical) ;;
        *) urgency="normal" ;;
      esac
    case "''${LANG:-en}" in
      fr*)
        title=$(printf '%s' "$title_fr" | base64 --decode) || return 0
        message=$(printf '%s' "$message_fr" | base64 --decode) || return 0
        ;;
      *)
        title=$(printf '%s' "$title_en" | base64 --decode) || return 0
        message=$(printf '%s' "$message_en" | base64 --decode) || return 0
        ;;
    esac

    # The queue mtime is the event time. Deliveries hours late (previous
    # run's failure shown at next login) must not read as "just happened":
    # annotate the original event date when older than an hour.
    event_epoch=$(stat -c %Y "$PENDING_NOTIFICATION_FILE" 2>/dev/null || true)
    if [ -n "$event_epoch" ]; then
      event_age=$(( $(date +%s) - event_epoch ))
      if [ "$event_age" -ge 3600 ]; then
        event_date=$(date -u -d "@$event_epoch" +%FT%TZ)
        case "''${LANG:-en}" in
          fr*) message="$message (événement du $event_date)" ;;
          *) message="$message (event of $event_date)" ;;
        esac
      fi
    fi

      if timeout \
        --signal=TERM \
        --kill-after=5s \
        "$NOTIFICATION_TIMEOUT" \
        notify-send \
        -u "$urgency" \
        -a "NixOS" \
        -i "${notifyIcon}" \
        -t ${toString notifyTimeout} \
        "$title" \
        "$message"; then
        mkdir -p "$notification_state_dir"
        notification_marker_tmp=$(mktemp "$notification_state_dir/.last-notification.XXXXXX")
        printf '%s\n' "$notification_id" > "$notification_marker_tmp"
        mv -f -- "$notification_marker_tmp" "$notification_marker"
        return 0
      fi
      return 1
    }
    # <<<END notifier-user
  '';

  root = ''
    # >>>BEGIN notifier-root
    # Anti-spam: each generation notifies at most once — re-runs on an
    # unchanged tree stay journal-only. Failures always notify.
    # Callers set $NOTIFIED_FILE and $last_notified (its cached content).
    # >>>BEGIN notifier-once
    note_once() {
      local sys="$1"
      shift
      if [[ "$last_notified" == "$sys" ]]; then
        _status INFO "$1: $2 (already notified, silent)"
        return 0
      fi
      _notify_or_queue "$@"
      echo "$sys" > "$NOTIFIED_FILE"
      last_notified="$sys"
    }
    # <<<END notifier-once
    _notify_user() {
      local uid="$1" user="$2" urgency="$3" title="$4" message="$5"

      timeout \
        --signal=TERM \
        --kill-after=5s \
        "$NOTIFICATION_TIMEOUT" \
        runuser -u "$user" -- env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        notify-send \
          -u "$urgency" \
          -a "NixOS" \
          -i "${notifyIcon}" \
          -t ${toString notifyTimeout} \
          "$title" \
          "$message"
    }

    _notify_all_users() {
      local title_fr="$1" message_fr="$2" title_en="$3" message_en="$4"
      local urgency="''${5:-normal}"
      local lang="''${LANG:-en}"
      local run_dir="''${AUTO_UPDATE_RUN_USER_DIR:-/run/user}"
      local notified_any=0
      local title message path uid user

      case "''${lang%%_*}" in
        fr) title="$title_fr"; message="$message_fr" ;;
        *) title="$title_en"; message="$message_en" ;;
      esac

      for path in "$run_dir"/*; do
        [ -d "$path" ] || continue
        [ -S "$path/bus" ] || continue
        uid=$(basename "$path")
        case "$uid" in
          ""|*[!0-9]*) continue ;;
        esac
        user=$(id -nu "$uid" 2>/dev/null) || continue
        [ -n "$user" ] || continue
        # Never notify the display-manager greeter itself.
        [ "$user" != "gdm" ] || continue

        if _notify_user "$uid" "$user" "$urgency" "$title" "$message"; then
          notified_any=1
        else
          _status WARNING "Unable to notify user $user."
        fi
      done

      [ "$notified_any" -eq 1 ]
    }

    _notify() {
      [ "$NOTIFICATIONS_ENABLED" -eq 1 ] || return 0
      _notify_all_users "$@"
    }

    _notify_or_queue() {
      local notification_queued=0

      [ "$NOTIFICATIONS_ENABLED" -eq 1 ] || return 0

      if _queue_pending_notification "$@"; then
        notification_queued=1
      else
        _status WARNING "Unable to prepare the desktop notification for deferred delivery."
      fi

      if _notify "$@"; then
        rm -f -- "$PENDING_NOTIFICATION_FILE"
      elif [ "$notification_queued" -eq 1 ]; then
        _status INFO "No active graphical session; notification queued for the next login."
      else
        _status WARNING "No active graphical session could be notified."
      fi
      return 0
    }

    _notify_failure() {
      local reason="unknown"
      local state_kind="" state_date="" stored_reason="" notification_status=""
      local title_fr message_fr title_en message_en
      local notified_any=0

      # Journal-only builds (no DE / notify=false) never queue: there will
      # never be a graphical login to deliver to.
      [ "$NOTIFICATIONS_ENABLED" -eq 1 ] || return 0

      if [ -f "$STATE_FILE" ]; then
        IFS='|' read -r state_kind state_date stored_reason notification_status < "$STATE_FILE" || true
        [ -n "$stored_reason" ] && reason="$stored_reason"
      fi

      # A detailed notification was already sent by _fail().
      [ "$state_kind" = "failed" ] && [ "$notification_status" = "notified" ] && return 0

      title_fr=$(_err_lookup "$reason" title_fr)
      message_fr=$(_err_lookup "$reason" body_fr)
      title_en=$(_err_lookup "$reason" title_en)
      message_en=$(_err_lookup "$reason" body_en)
      [ -n "$title_en" ] || {
        title_fr="Mise à jour NixOS — Erreur système"
        message_fr="La mise à jour automatique a échoué (motif : $reason). Voir $LOG_FILE."
        title_en="NixOS Update — System error"
        message_en="Automatic update failed (reason: $reason). See $LOG_FILE."
      }

      if _notify_all_users \
        "$title_fr" "$message_fr" "$title_en" "$message_en" "critical"; then
        notified_any=1
      fi
      if [ "$notified_any" -eq 1 ]; then
        rm -f -- "$PENDING_NOTIFICATION_FILE"
      elif _queue_pending_notification \
        "$title_fr" "$message_fr" "$title_en" "$message_en" "critical"; then
        _status INFO "No active graphical session; failure notification queued for the next login."
      else
        _status WARNING "No active graphical session could be notified and the notification could not be queued."
      fi
      return 0
    }
    # <<<END notifier-root
  '';
in
{
  inherit user;
  full = user + root;
}
