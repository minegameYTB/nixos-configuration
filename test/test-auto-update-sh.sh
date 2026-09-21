#!/usr/bin/env bash
### Logic tests for the auto-update shell fragments (no duplication):
### sources the real functions from configurations/modules/misc/auto-update/
### via test/lib-fragments.sh, stubs runuser/id/notify-send, and checks the
### bilingual notifier + dedup + health logic.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-fragments.sh
source "$REPO/test/lib-fragments.sh"
T=/tmp/opencode/autoupdate-test
rm -rf "$T"; mkdir -p "$T/fakebin" "$T/rundir"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# ── resolve Nix interpolations in fragments with test values ──
fragment errors.nix errors > "$T/errors.func"
fragment output.nix output-core > "$T/output.func"
fragment output.nix output-render > "$T/output-render.func"
fragment notifier.nix notifier-user > "$T/notifier-user.func"
fragment notifier.nix notifier-root > "$T/notifier-root.func"
fragment notifier.nix notifier-once > "$T/notifier-once.func"
fragment notifier.nix reboot-waiter > "$T/notifier-waiter.func"
fragment health.nix health > "$T/health.func"
sed -e 's|\${toString notifyTimeout}|10000|' -e 's|\${notifyIcon}|nix-snowflake-white|' \
  "$T/notifier-user.func" > "$T/nu.func"
sed -e 's|\${toString notifyTimeout}|10000|' -e 's|\${notifyIcon}|nix-snowflake-white|' \
  "$T/notifier-root.func" > "$T/nr.func"
sed -e 's|\${notifyIcon}|nix-snowflake-white|' \
  "$T/notifier-waiter.func" > "$T/nw.func"
# Fragments carry Nix `''${...}` escapes: resolve them to plain bash ${...}.
sed -i "s|''\${|\${|g" "$T/nu.func" "$T/nr.func" "$T/nw.func" "$T/output-render.func"
# errors.toBash is Nix-generated; emulate the two codes under test.
cat > "$T/errors.func" <<'EOF'
_err_lookup() {
  case "$1:$2" in
    rebuild-boot:urgency) printf '%s' "critical" ;;
    rebuild-boot:title_fr) printf '%s' "Mise à jour NixOS — Reconstruction échouée" ;;
    rebuild-boot:body_fr) printf '%s' "La reconstruction du système a échoué." ;;
    rebuild-boot:title_en) printf '%s' "NixOS Update — Rebuild failed" ;;
    rebuild-boot:body_en) printf '%s' "System rebuild failed." ;;
    *) printf '%s' "" ;;
  esac
}
EOF
sed -e 's|\${lib.escapeShellArgs cfg.healthCheck.units}|sshd.service cron.service|' \
    -e 's|\${lib.boolToString cfg.healthCheck.requireNetwork}|true|' \
    -e 's|\${lib.boolToString cfg.healthCheck.checkFailedUnits}|true|' \
    -e "s|''\\\${PROC_NET_ROUTE:-/proc/net/route}|\${PROC_NET_ROUTE}|" \
    -e "s|''\\\${AUTO_UPDATE_BOOTED_SYSTEM:-/run/booted-system}|\${AUTO_UPDATE_BOOTED_SYSTEM}|" \
    -e 's|\${lib.boolToString cfg.healthCheck.autoRollback}|false|' \
    -e 's|\${lib.boolToString cfg.allowReboot}|false|' \
  "$T/health.func" > "$T/health.resolved"
# (Nix `''${...}` escapes resolved globally below with the `true` variant.)
sed -e 's|\${lib.escapeShellArgs cfg.healthCheck.units}|sshd.service cron.service|' \
    -e 's|\${lib.boolToString cfg.healthCheck.requireNetwork}|true|' \
    -e 's|\${lib.boolToString cfg.healthCheck.checkFailedUnits}|true|' \
    -e "s|''\\\${PROC_NET_ROUTE:-/proc/net/route}|\${PROC_NET_ROUTE}|" \
    -e "s|''\\\${AUTO_UPDATE_BOOTED_SYSTEM:-/run/booted-system}|\${AUTO_UPDATE_BOOTED_SYSTEM}|" \
    -e 's|\${lib.boolToString cfg.healthCheck.autoRollback}|true|' \
    -e 's|\${lib.boolToString cfg.allowReboot}|false|' \
  "$T/health.func" > "$T/health.true"
sed -e 's|\${lib.escapeShellArgs cfg.healthCheck.units}|sshd.service cron.service|' \
    -e 's|\${lib.boolToString cfg.healthCheck.requireNetwork}|true|' \
    -e 's|\${lib.boolToString cfg.healthCheck.checkFailedUnits}|true|' \
    -e "s|''\\\${PROC_NET_ROUTE:-/proc/net/route}|\${PROC_NET_ROUTE}|" \
    -e "s|''\\\${AUTO_UPDATE_BOOTED_SYSTEM:-/run/booted-system}|\${AUTO_UPDATE_BOOTED_SYSTEM}|" \
    -e 's|\${lib.boolToString cfg.healthCheck.autoRollback}|true|' \
    -e 's|\${lib.boolToString cfg.allowReboot}|true|' \
  "$T/health.func" > "$T/health.rb"
sed -i "s|''\${|\${|g" "$T/health.resolved" "$T/health.true" "$T/health.rb"

grep -q '^[ \t]*_notify_all_users() {' "$T/nr.func" && grep -q '_notify_user' "$T/nr.func" \
  && ok "notifier-root extracted intact" || ko "notifier-root extraction broken"
grep -q '^[ \t]*_notify_reboot_waiter() {' "$T/nw.func" && grep -q '_notify_reboot_with_actions' "$T/nw.func" \
  && ok "reboot-waiter extracted intact" || ko "reboot-waiter extraction broken"
grep -q '^[ \t]*check_health() {' "$T/health.resolved" \
  && ok "health extracted intact" || ko "health extraction broken"
grep -q '^_err_lookup() {' "$T/errors.func" \
  && ok "errors stub in place" || ko "errors stub missing"

# ── stubs ──
cat > "$T/fakebin/id" <<'EOF'
#!/usr/bin/env bash
# maps Codes/uids/1000... no: id -nu <uid>
if [[ "${1:-}" == "-nu" ]]; then
  case "${2:-}" in
    1000) echo minegame;;
    120) echo gdm;;
    *) exit 1;;
  esac
else
  exit 1
fi
EOF
cat > "$T/fakebin/runuser" <<'EOF'
#!/usr/bin/env bash
echo "RUNUSER: $*" >> "$CALLS"
exit 0
EOF
cat > "$T/fakebin/timeout" <<'EOF'
#!/usr/bin/env bash
# drop --signal/--kill-after/duration, exec the rest
args=()
skip=0
for a in "$@"; do
  if (( skip > 0 )); then skip=$((skip-1)); continue; fi
  case "$a" in
    --signal|--kill-after) skip=1; continue;;
    --signal=*|--kill-after=*) continue;;
    --) continue;;
    [0-9]*s|[0-9]*m|[0-9]*h) [[ "${#args[@]}" -eq 0 ]] && continue;;
  esac
  args+=("$a")
done
exec "${args[@]}"
EOF
chmod +x "$T/fakebin/"*
export PATH="$T/fakebin:$PATH"
export CALLS="$T/calls.log"

BASE_PRELUDE='
log() { :; }
_status() { :; }
STATE_DIR="/tmp/opencode/autoupdate-test/state"
STATE_FILE="$STATE_DIR/last-rebuild-status"
LOG_FILE="$STATE_DIR/test.log"
PENDING_NOTIFICATION_FILE="$STATE_DIR/pending-notification"
NOTIFICATION_TIMEOUT=15s
mkdir -p "$STATE_DIR"
'

run_notify_all(){
  local rundir="$1" notif="$2" lang="${3:-en}"
  : > "$CALLS"
  AUTO_UPDATE_RUN_USER_DIR="$rundir" NOTIFICATIONS_ENABLED="$notif" LANG="$lang" bash -c "
    $BASE_PRELUDE
    source "$T/nu.func"
    source "$T/nr.func"
    _notify 'titre FR' 'corps FR' 'title EN' 'body EN' normal
  " 2>/dev/null || true
}

mksock(){
  # $1 = dir/uid : create a real unix socket at <dir>/bus
  mkdir -p "$1"
  python3 -c "import socket; s = socket.socket(socket.AF_UNIX); s.bind('$1/bus')"
}

# ── notify cases ──
mkdir -p "$T/rundir-user/1000"
mksock "$T/rundir-user/1000"
run_notify_all "$T/rundir-user" 1
grep -q 'RUNUSER:.*-u minegame.*notify-send' "$CALLS" \
  && ok "active user → notify-send via runuser" || ko "active user not notified"
grep -q 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus' "$CALLS" \
  && ok "dbus env targets user bus" || ko "dbus env wrong"
grep -q 'notify-send .* -t 10000' "$CALLS" \
  && ok "notification carries a timeout" || ko "notification timeout missing"
grep -q 'notify-send -u normal' "$CALLS" \
  && ok "urgency flag carries a real urgency (arg-order regression)" || ko "urgency flag broken"

run_notify_all "$T/rundir-empty" 1
[[ ! -s "$CALLS" ]] && ok "no session → silent (journal only)" || ko "notified with no session"

mkdir -p "$T/rundir-gdm/120"
mksock "$T/rundir-gdm/120"
run_notify_all "$T/rundir-gdm" 1
[[ ! -s "$CALLS" ]] && ok "gdm greeter session ignored" || ko "gdm was notified"

run_notify_all "$T/rundir-user" 0
[[ ! -s "$CALLS" ]] && ok "notify disabled → silent" || ko "notified while disabled"

LANG=fr AUTO_UPDATE_RUN_USER_DIR="$T/rundir-user" NOTIFICATIONS_ENABLED=1 bash -c "
  $BASE_PRELUDE
  source \"$T/nu.func\"
  source \"$T/nr.func\"
  _notify 'titre FR' 'corps FR' 'title EN' 'body EN' normal
" 2>/dev/null || true
grep -q 'titre FR' "$CALLS" \
  && ok "LANG=fr picks French title" || ko "French title not picked"

# ── _notify_or_queue fallback: no session → queued bilingual ──
rm -f "$T/state/pending-notification"
AUTO_UPDATE_RUN_USER_DIR="$T/rundir-empty" NOTIFICATIONS_ENABLED=1 bash -c "
  $BASE_PRELUDE
  source \"$T/nu.func\"
  source \"$T/nr.func\"
  _notify_or_queue 'titre FR' 'corps FR' 'title EN' 'body EN' normal
" 2>/dev/null || true
[[ -f "$T/state/pending-notification" ]] \
  && ok "headless notify → queued for next login" || ko "headless notify not queued"

# ── pending delivery dedup (user service path) ──
export HOME="$T/home" XDG_STATE_HOME="$T/home/.local/state"
mkdir -p "$HOME"
DELIVER='
source "'"$T/nu.func"'"
STATE_DIR="'"$T/state"'"
_init_notifier
PENDING_NOTIFICATION_FILE="'"$T/state/pending-notification"'"
_deliver_pending_notification
'
cat > "$T/fakebin/notify-send" <<'EOF'
#!/usr/bin/env bash
echo "NOTIFY-SEND: $*" >> "$CALLS"
exit 0
EOF
chmod +x "$T/fakebin/notify-send"
: > "$CALLS"
bash -c "$DELIVER" 2>/dev/null || true
grep -q 'NOTIFY-SEND' "$CALLS" \
  && ok "pending notification delivered at login" || ko "pending delivery failed"
: > "$CALLS"
bash -c "$DELIVER" 2>/dev/null || true
[[ ! -s "$CALLS" ]] && ok "delivered notification not repeated (id dedup)" || ko "pending delivered twice"

# ── stale delivery carries the event date (no "just happened" confusion) ──
rm -f "$T/home/.local/state/nixos-auto-update/last-notification"
AUTO_UPDATE_RUN_USER_DIR="$T/rundir-empty" NOTIFICATIONS_ENABLED=1 bash -c "
  $BASE_PRELUDE
  source \"$T/nu.func\"
  source \"$T/nr.func\"
  _notify_or_queue 'titre FR' 'corps FR' 'title EN' 'body EN' normal
" 2>/dev/null || true
touch -d '3 hours ago' "$T/state/pending-notification"
: > "$CALLS"
bash -c "$DELIVER" 2>/dev/null || true
grep -q 'NOTIFY-SEND' "$CALLS" && grep -qE 'événement du [0-9]{4}|event of [0-9]{4}' "$CALLS" \
  && ok "stale delivery annotates the event date" || ko "stale delivery not annotated"
rm -f "$T/home/.local/state/nixos-auto-update/last-notification"
AUTO_UPDATE_RUN_USER_DIR="$T/rundir-empty" NOTIFICATIONS_ENABLED=1 bash -c "
  $BASE_PRELUDE
  source \"$T/nu.func\"
  source \"$T/nr.func\"
  _notify_or_queue 'titre FR' 'corps FR' 'title EN' 'body EN' normal
" 2>/dev/null || true
: > "$CALLS"
bash -c "$DELIVER" 2>/dev/null || true
grep -q 'NOTIFY-SEND' "$CALLS" && ! grep -qE 'événement du|event of' "$CALLS" \
  && ok "fresh delivery has no event-date annotation" || ko "fresh delivery wrongly annotated"

# ── _prefix_lines + _filter_git_progress (uniform log rendering) ──
PREFIX_PRE='
source "'"$T/output-render.func"'"
_status() { printf "STATUS[%s]: %s\n" "$1" "$2" >> "'"$CALLS"'"; }
INTERACTIVE_OUTPUT=0
'
: > "$CALLS"
printf 'plain\n\033[1;31mred\033[0m\nmixed \033[36mcyan\033[0m end\nend\rof\n' \
  | bash -c "$PREFIX_PRE
_prefix_lines INFO" 2>/dev/null || true
grep -q 'STATUS\[INFO\]: plain' "$CALLS" \
  && grep -q 'STATUS\[INFO\]: red$' "$CALLS" \
  && grep -q 'STATUS\[INFO\]: mixed cyan end' "$CALLS" \
  && grep -q 'STATUS\[INFO\]: endof' "$CALLS" \
  && ! grep -q "$(printf '\033')" "$CALLS" \
  && ! grep -q "$(printf '\r')" "$CALLS" \
  && ok "prefix_lines: [INFO] prefix, ANSI + CR stripped" || ko "prefix_lines broken"
: > "$CALLS"
printf '%s\n' 'remote: Enumerating objects: 10, done.' 'Receiving objects:  50% (5/10)' 'remote: useful warning' 'Update completed.' \
  | bash -c "$PREFIX_PRE
_filter_git_progress" > "$T/filter.out" 2>/dev/null || true
grep -q 'useful warning' "$T/filter.out" && grep -q 'Update completed' "$T/filter.out" \
  && ! grep -q 'Enumerating\|50% (5/10)' "$T/filter.out" \
  && ok "git progress filter drops counters, keeps useful output" || ko "git progress filter broken"

# ── note_once dedup + arg order (generation spam guard) ──
run_note(){
  local last="$1" sys="$2"
  : > "$CALLS"; rm -f "$T/nstate"; [[ -n "$last" ]] && echo "$last" > "$T/nstate"
  bash -c "
    _status() { echo \"STATUS: \$*\"; }
    _notify_or_queue() { echo \"NOTIFY: \$*\" >> \"$CALLS\"; }
    NOTIFIED_FILE=\"$T/nstate\"
    last_notified=\$(cat \"\$NOTIFIED_FILE\" 2>/dev/null || true)
    source \"$T/notifier-once.func\"
    note_once \"$sys\" 'titre FR' 'corps FR' 'title EN' 'body EN' normal
  " > "$T/note.out" 2>&1 || true
}

run_note "" "/sys-A"
grep -q 'NOTIFY: titre FR corps FR title EN body EN normal' "$CALLS" \
  && [[ "$(cat "$T/nstate")" == "/sys-A" ]] \
  && ok "first sight → notify (texts first, urgency last) + state stored" || ko "first sight failed"

run_note "/sys-A" "/sys-A"
! grep -q 'NOTIFY' "$CALLS" && grep -q 'already notified, silent' "$T/note.out" \
  && ok "unchanged generation → silent, journal only" || ko "spam on unchanged generation"

run_note "/sys-A" "/sys-B"
grep -q 'NOTIFY' "$CALLS" && [[ "$(cat "$T/nstate")" == "/sys-B" ]] \
  && ok "new generation → notify + state updated" || ko "new generation not notified"

# ── _notify_failure paths ──
FAIL_PRE='
source "'"$T/errors.func"'"
source "'"$T/nu.func"'"
source "'"$T/nr.func"'"
_status() { echo "STATUS: $*" >> "'"$CALLS"'"; }
STATE_DIR="'"$T/state"'"
STATE_FILE="$STATE_DIR/last-rebuild-status"
LOG_FILE="$STATE_DIR/test.log"
PENDING_NOTIFICATION_FILE="$STATE_DIR/pending-notification"
NOTIFICATION_TIMEOUT=15s
NOTIFICATIONS_ENABLED=1
'
printf 'failed|2026-01-01T00:00:00|rebuild-boot|pending' > "$T/state/last-rebuild-status"
rm -f "$T/state/pending-notification"
: > "$CALLS"
LANG=C AUTO_UPDATE_RUN_USER_DIR="$T/rundir-user" bash -c "$FAIL_PRE
_notify_failure" 2>/dev/null || true
grep -q 'RUNUSER:.*Rebuild failed' "$CALLS" \
  && ok "failure with session → immediate bilingual notify (catalogue)" || ko "failure notify broken"

printf 'failed|2026-01-01T00:00:00|rebuild-boot|notified' > "$T/state/last-rebuild-status"
: > "$CALLS"
AUTO_UPDATE_RUN_USER_DIR="$T/rundir-user" bash -c "$FAIL_PRE
_notify_failure" 2>/dev/null
[[ ! -s "$CALLS" ]] && ok "already-notified failure → silent" || ko "already-notified failure re-notified"

printf 'failed|2026-01-01T00:00:00|rebuild-boot|pending' > "$T/state/last-rebuild-status"
rm -f "$T/state/pending-notification"
: > "$CALLS"
AUTO_UPDATE_RUN_USER_DIR="$T/rundir-empty" bash -c "$FAIL_PRE
_notify_failure" 2>/dev/null
[[ -f "$T/state/pending-notification" ]] \
  && ok "headless failure → queued" || ko "headless failure not queued"

# ── check_health cases ──
cat > "$T/fakebin/systemctl" <<'EOF'
#!/usr/bin/env bash
# is-active --quiet <unit> -> 0 iff listed in $ACTIVE_UNITS
if [[ "${1:-}" == "is-active" ]]; then
  [[ " $ACTIVE_UNITS " == *" ${@: -1} "* ]] && exit 0 || exit 3
fi
# list-units -> lines from $FAILED_UNITS (empty = none failed)
if [[ "${1:-}" == "list-units" ]]; then
  printf '%s' "$FAILED_UNITS"
  exit 0
fi
exit 0
EOF
chmod +x "$T/fakebin/systemctl"
printf 'Iface\tDestination\tGateway\tFlags\neth0\t00000000\t0101A8C0\t0003\nlo\t00000000\t00000000\t0001\n' > "$T/route-good"
printf 'Iface\tDestination\tGateway\tFlags\nlo\t00000000\t00000000\t0001\n' > "$T/route-bad"

run_health(){
  local units="$1" route="$2" failed="${3:-}"
  if ACTIVE_UNITS="$units" PROC_NET_ROUTE="$route" FAILED_UNITS="$failed" \
    bash -c "_status() { echo \"STATUS: \$*\"; }; source \"$T/health.resolved\"; check_health" > "$T/health.out" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  HRc=$rc
}

run_health "sshd.service cron.service" "$T/route-good"
(( HRc == 0 )) && ok "healthy units + route → 0" || ko "healthy case failed"

run_health "sshd.service" "$T/route-good"
(( HRc != 0 )) && grep -q 'unhealthy unit: cron.service' "$T/health.out" \
  && ok "down unit → 1 + logged" || ko "down unit not detected"

run_health "sshd.service cron.service" "$T/route-bad"
(( HRc != 0 )) && grep -q 'no default IPv4 route' "$T/health.out" \
  && ok "missing route → 1 + logged" || ko "missing route not detected"

run_health "sshd.service cron.service" "$T/route-good" "foo.service● loaded failed failed Foo"
(( HRc != 0 )) && grep -q 'failed units present' "$T/health.out" \
  && ok "failed unit → 1 + logged" || ko "failed unit not detected"

# ── _validate_staged_boot (phase validating) ──
setup_vstate(){
  local dir="$T/vstate-$1"
  rm -rf "$dir"; mkdir -p "$dir"
  VDIR="$dir"
}
run_validate(){
  local healthfile="$1" healthy="$2" verdict
  if HEALTHY="$healthy" VDIR="$VDIR" BOOTED_SYS="$VDIR/booted" bash -c "
    _status() { echo \"STATUS: \$*\" >> \"\$VDIR/calls\"; }
    _write_state() { echo \"STATE: \$*\" >> \"\$VDIR/calls\"; }
    _notify_or_queue() { echo \"NOTIFY: \$*\" >> \"\$VDIR/calls\"; return 0; }
    _switch_boot_to_system() { echo \"SWITCH: \$*\" >> \"\$VDIR/calls\"; return 0; }
    systemctl() { echo \"SYSTEMCTL: \$*\" >> \"\$VDIR/calls\"; return 0; }
    source \"$healthfile\"
    check_health() { return \"\$HEALTHY\"; }
    STATE_DIR=\"\$VDIR\" STATE_FILE=\"\$VDIR/status\" LOG_FILE=\"\$VDIR/log\"
    STAGED_FILE=\"\$VDIR/staged\" INHIBITED_FILE=\"\$VDIR/inhibited\"
    PREVIOUS_FILE=\"\$VDIR/previous\" ROLLED_BACK_FILE=\"\$VDIR/rolled-back\"
    REBUILD_BOOT_TIMEOUT=1h NOTIFICATIONS_ENABLED=1
    AUTO_UPDATE_BOOTED_SYSTEM=\"\$BOOTED_SYS\"
    _validate_staged_boot
  " > /dev/null 2>&1; then
    verdict=0
  else
    verdict=$?
  fi
  VRC=$verdict
}

setup_vstate no-staged
: > "$VDIR/calls"
run_validate "$T/health.resolved" 0
(( VRC == 0 )) && grep -q 'nothing to validate' "$VDIR/calls" \
  && ok "no staged file → silent 0" || ko "no-staged path broken"

setup_vstate mismatch
echo "/nix/store/aaa-system" > "$VDIR/staged"
ln -sfn /nix/store/bbb-system "$VDIR/booted"
: > "$VDIR/calls"
run_validate "$T/health.resolved" 0
(( VRC == 0 )) && grep -q 'not the staged' "$VDIR/calls" \
  && ok "booted != staged → silent 0" || ko "mismatch path broken"

setup_vstate healthy
echo "/nix/store/aaa-system" > "$VDIR/staged"
ln -sfn /nix/store/aaa-system "$VDIR/booted"
: > "$VDIR/calls"
run_validate "$T/health.resolved" 0
(( VRC == 0 )) && [[ ! -f "$VDIR/staged" ]] && grep -q 'adopted' "$VDIR/calls" \
  && ok "healthy staged boot → adopted" || ko "healthy path broken"

setup_vstate sick
echo "/nix/store/aaa-system" > "$VDIR/staged"
ln -sfn /nix/store/aaa-system "$VDIR/booted"
: > "$VDIR/calls"
run_validate "$T/health.resolved" 1
(( VRC != 0 )) && [[ -f "$VDIR/inhibited" ]] && grep -q 'NOTIFY' "$VDIR/calls" \
  && ! grep -q 'SWITCH' "$VDIR/calls" \
  && ok "sick staged boot → inhibited, no auto-rollback by default" || ko "sick path broken"

setup_vstate sick-rb
echo "/nix/store/aaa-system" > "$VDIR/staged"
echo "/nix/store/old-healthy-system" > "$VDIR/previous"
ln -sfn /nix/store/aaa-system "$VDIR/booted"
: > "$VDIR/calls"
run_validate "$T/health.true" 1
(( VRC != 0 )) && grep -q 'SWITCH: /nix/store/old-healthy-system' "$VDIR/calls" \
  && [[ -f "$VDIR/rolled-back" && -f "$VDIR/inhibited" ]] \
  && ! grep -q 'SYSTEMCTL' "$VDIR/calls" \
  && ok "sick + autoRollback → previous restored (one-shot, inhibit kept)" || ko "rollback path broken"

setup_vstate sick-rb-reboot
echo "/nix/store/aaa-system" > "$VDIR/staged"
echo "/nix/store/old-healthy-system" > "$VDIR/previous"
ln -sfn /nix/store/aaa-system "$VDIR/booted"
: > "$VDIR/calls"
run_validate "$T/health.rb" 1
(( VRC != 0 )) && grep -q 'SWITCH: /nix/store/old-healthy-system' "$VDIR/calls" \
  && grep -q 'SYSTEMCTL: reboot' "$VDIR/calls" \
  && [[ -f "$VDIR/rolled-back" && -f "$VDIR/inhibited" ]] \
  && ok "sick + autoRollback + allowReboot → restored + reboot" || ko "rollback+reboot path broken"

# ── _notify_reboot_waiter (interactive reboot notice) ──
# runuser stub: drop the `-u <uid> --` prefix, exec the rest (real env
# assignments + fake notify-send from PATH). notify-send stub: print
# $WAIT_ACTION (the clicked action id, empty = dismissed), exit $WAIT_RC.
cat > "$T/fakebin/runuser" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-u" ]]; then shift 2; fi
if [[ "${1:-}" == "--" ]]; then shift; fi
exec "$@"
EOF
cat > "$T/fakebin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${WAIT_ACTION:-}"
exit "${WAIT_RC:-0}"
EOF
chmod +x "$T/fakebin/runuser" "$T/fakebin/notify-send"
run_waiter(){
  local action="$1" rc="$2"
  local marker="$T/waiter-marker"
  rm -f -- "$marker"
  if WAIT_ACTION="$action" WAIT_RC="$rc" bash -c "
    source \"$T/nw.func\"
    _notify_reboot_waiter 1000 minegame \"$marker\" Reporter 'titre' 'corps'
  " 2>/dev/null; then
    WRC=0
  else
    WRC=$?
  fi
}
run_waiter postpone 0
(( WRC == 0 )) && [[ -f "$T/waiter-marker" ]] \
  && ok "click Reporter → postpone marker created" || ko "click did not create the marker"
run_waiter "" 0
(( WRC == 0 )) && [[ ! -f "$T/waiter-marker" ]] \
  && ok "dismissed notice → no marker, waiter stays green" || ko "dismiss wrongly handled"
run_waiter "" 1
(( WRC == 0 )) && [[ ! -f "$T/waiter-marker" ]] \
  && ok "failing notify-send → no marker, waiter stays green" || ko "backend failure wrongly handled"

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
