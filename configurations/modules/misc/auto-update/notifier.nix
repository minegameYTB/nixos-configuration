# configurations/modules/misc/auto-update/notifier.nix — immediate and
# deferred desktop notifications for the auto-update services.
#
# Split (PATH-hygiene: the per-user pending service runs with coreutils +
# libnotify only):
#   user — _init_notifier, _queue_pending_notification,
#          _deliver_pending_notification (coreutils + libnotify only)
#   full — user + _notify_user, _notify_all_users, _notify,
#          _notify_or_queue, _notify_failure,
#          _notify_reboot_waiter, _notify_reboot_with_actions
#          (adds util-linux runuser)
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

      # This function is called from `if _queue...`, where bash disables
      # errexit for the whole body: every step must report failure itself,
      # otherwise a failed mkdir/mktemp/mv looked like a successful queue.
      mkdir -p "$STATE_DIR" || return 1
      notification_tmp=$(mktemp "$STATE_DIR/.pending-notification.XXXXXX") || return 1
      notification_id="$(date +%s%N)-$$"
      if ! printf '%s|%s|%s|%s|%s|%s\n' \
        "$notification_id" \
        "$urgency" \
        "$(printf '%s' "$1" | base64 -w 0)" \
        "$(printf '%s' "$2" | base64 -w 0)" \
        "$(printf '%s' "$3" | base64 -w 0)" \
        "$(printf '%s' "$4" | base64 -w 0)" \
        > "$notification_tmp"; then
        rm -f -- "$notification_tmp"
        return 1
      fi
      if ! chmod 0644 "$notification_tmp" \
        || ! mv -f -- "$notification_tmp" "$PENDING_NOTIFICATION_FILE"; then
        rm -f -- "$notification_tmp"
        return 1
      fi
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
      if ! _notify_or_queue "$@"; then
        _status WARNING "Notification could not be delivered or queued; it will be retried on the next run."
        return 0
      fi
      echo "$sys" > "$NOTIFIED_FILE"
      last_notified="$sys"
    }
    # <<<END notifier-once
    _user_lang() {
      # Prefer the language of the user's systemd session over the service's
      # LANG: the root service inherits the system locale, which can differ
      # from what the logged-in user chose. Fall back to the caller's LANG.
      local uid="$1" user="$2" env_dump="" lang=""

      env_dump=$(timeout --signal=TERM 2s runuser -u "$user" -- env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        systemctl --user show-environment 2>/dev/null) || true
      case "$env_dump" in
        LANG=*) lang="$env_dump" ;;
        *$'\nLANG='*) lang="''${env_dump#*$'\n'LANG=}" ;;
      esac
      lang="''${lang%%$'\n'*}"
      printf '%s' "$lang"
    }

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
      local notified_any=0 failed_any=0
      local title message path uid user user_lang

      for path in "$run_dir"/*; do
        [ -d "$path" ] || continue
        [ -S "$path/bus" ] || continue
        uid=$(basename "$path")
        case "$uid" in
          ""|*[!0-9]*) continue ;;
        esac
        user=$(id -nu "$uid" 2>/dev/null) || continue
        [ -n "$user" ] || continue
        # Never notify a display-manager greeter itself.
        case "$user" in
          gdm|lightdm|sddm|greeter) continue ;;
        esac

        user_lang=$(_user_lang "$uid" "$user")
        [ -n "$user_lang" ] || user_lang="$lang"
        case "''${user_lang%%_*}" in
          fr) title="$title_fr"; message="$message_fr" ;;
          *) title="$title_en"; message="$message_en" ;;
        esac

        if _notify_user "$uid" "$user" "$urgency" "$title" "$message"; then
          notified_any=1
        else
          failed_any=1
          _status WARNING "Unable to notify user $user."
        fi
      done

      # 0 = all live sessions notified, 2 = only some, 1 = none.
      [ "$notified_any" -eq 1 ] || return 1
      [ "$failed_any" -eq 0 ] || return 2
      return 0
    }

    _notify() {
      [ "$NOTIFICATIONS_ENABLED" -eq 1 ] || return 0
      _notify_all_users "$@"
    }

    # >>>BEGIN reboot-waiter
    _notify_reboot_waiter() {
      # One interactive reboot notice for a single graphical session:
      # shows a "Ne pas redémarrer maintenant" button and touches $3
      # (the reboot cancel marker) when clicked. Dismissed, expired or
      # failed delivery exits quietly: dismiss != cancel, and a missing
      # action backend must never fail the update run.
      local uid="$1" user="$2" marker="$3" action_label="$4" title="$5" message="$6"
      local action=""

      # Deliberately no NOTIFICATION_TIMEOUT wrapper here: --wait must
      # survive the whole reboot window (a timeout would dismiss the
      # notice early). -t 0 asks for no server-side expiry; critical
      # urgency persists on GNOME regardless.
      if ! action=$(runuser -u "$user" -- env \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        notify-send \
          -u "critical" \
          -a "NixOS" \
          -i "${notifyIcon}" \
          -t 0 \
          -A "cancel=$action_label" \
          "$title" \
          "$message" 2>/dev/null); then
        return 1
      fi
      if [ "$action" = "cancel" ]; then
        touch "$marker"
      fi
      return 0
    }

    _notify_reboot_with_actions() {
      # Fan-out of the interactive reboot notice to every live graphical
      # session (same scan as _notify_all_users): each waiter runs in the
      # background and only ever touches $1 on click. Appends waiter PIDs
      # to $2 for the caller to kill once the window closes; waiters also
      # die with the service (control-group). A late click can only touch
      # the marker, which the window-start guard then ignores.
      #
      # Return value is the caller's dedup signal, not a success flag:
      #   0 — at least one session got the interactive notice (identical
      #       title/body, plus the "Ne pas redémarrer maintenant" button). The caller
      #       must NOT also send the actionless copy, or the same
      #       deadline pops up twice in the same session.
      #   1 — nothing could be notified interactively: notifications
      #       disabled, no live graphical session, or no usable pidfile.
      #       The caller must then fall back to the actionless notice,
      #       which is the only one that can be queued for a later login.
      local marker="$1" pidfile="$2"
      local title_fr="$3" message_fr="$4" title_en="$5" message_en="$6"
      local lang="''${LANG:-en}"
      local run_dir="''${AUTO_UPDATE_RUN_USER_DIR:-/run/user}"
      local title message action_label user_lang path uid user
      local waiter_pid waiter_count=0 delivered=0 waiter_rc
      local resultfile="''${pidfile}.results"

      [ "$NOTIFICATIONS_ENABLED" -eq 1 ] || return 1

      : > "$pidfile" || return 1
      : > "$resultfile" || return 1
      for path in "$run_dir"/*; do
        [ -d "$path" ] || continue
        [ -S "$path/bus" ] || continue
        uid=$(basename "$path")
        case "$uid" in
          ""|*[!0-9]*) continue ;;
        esac
        user=$(id -nu "$uid" 2>/dev/null) || continue
        [ -n "$user" ] || continue
        # Never notify a display-manager greeter itself.
        case "$user" in
          gdm|lightdm|sddm|greeter) continue ;;
        esac

        user_lang=$(_user_lang "$uid" "$user")
        [ -n "$user_lang" ] || user_lang="$lang"
        case "''${user_lang%%_*}" in
          fr) title="$title_fr"; message="$message_fr"; action_label="Ne pas redémarrer maintenant" ;;
          *) title="$title_en"; message="$message_en"; action_label="Don't reboot now" ;;
        esac

        ( waiter_rc=0
          _notify_reboot_waiter "$uid" "$user" "$marker" "$action_label" "$title" "$message" || waiter_rc=$?
          echo "$waiter_rc" >> "$resultfile"
        ) &
        waiter_pid=$!
        echo "$waiter_pid" >> "$pidfile"
        waiter_count=$((waiter_count + 1))
      done
      [ "$waiter_count" -gt 0 ] || return 1

      # A waiter lives until the notice is clicked/dismissed, so a still-empty
      # result file after this short grace means delivery is in progress (the
      # normal case). An immediate non-zero result is a delivery failure and
      # must let the caller fall back to the queue-able actionless notice.
      sleep 1
      if [ -s "$resultfile" ]; then
        while read -r waiter_rc; do
          if [ "$waiter_rc" -eq 0 ]; then delivered=1; fi
        done < "$resultfile"
        [ "$delivered" -eq 1 ] || return 1
      fi
      return 0
    }
    # <<<END reboot-waiter

    _notify_or_queue() {
      local notification_queued=0
      local notify_rc=1

      [ "$NOTIFICATIONS_ENABLED" -eq 1 ] || return 0

      if _queue_pending_notification "$@"; then
        notification_queued=1
      else
        _status WARNING "Unable to prepare the desktop notification for deferred delivery."
      fi

      notify_rc=0
      _notify "$@" || notify_rc=$?
      if [ "$notify_rc" -eq 0 ]; then
        # Every live session got it; a partial fan-out (2) keeps the pending
        # copy for the users that could not be reached.
        rm -f -- "$PENDING_NOTIFICATION_FILE"
      elif [ "$notification_queued" -eq 1 ]; then
        if [ "$notify_rc" -eq 2 ]; then
          _status INFO "Some sessions could not be notified; notification queued for them."
        else
          _status INFO "No active graphical session; notification queued for the next login."
        fi
      else
        _status WARNING "No active graphical session could be notified and the notification could not be queued."
        return 1
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

      local notify_rc=0
      _notify_all_users \
        "$title_fr" "$message_fr" "$title_en" "$message_en" "critical" || notify_rc=$?
      if [ "$notify_rc" -eq 0 ]; then
        notified_any=1
      fi
      if [ "$notified_any" -eq 1 ]; then
        rm -f -- "$PENDING_NOTIFICATION_FILE"
      elif _queue_pending_notification \
        "$title_fr" "$message_fr" "$title_en" "$message_en" "critical"; then
        if [ "$notify_rc" -eq 2 ]; then
          _status INFO "Some sessions could not be notified; failure notification queued for them."
        else
          _status INFO "No active graphical session; failure notification queued for the next login."
        fi
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
