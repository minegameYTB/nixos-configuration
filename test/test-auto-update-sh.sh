#!/usr/bin/env bash
### Logic tests for the shell embedded in modules/misc/auto-update.nix.
### Extracts the real functions from the module file (no duplication),
### stubs loginctl/id/runuser/notify-send, and checks notify + reboot logic.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="$REPO/configurations/modules/misc/auto-update.nix"
T=/tmp/opencode/autoupdate-test
rm -rf "$T"; mkdir -p "$T/fakebin" "$T/trees/booted" "$T/trees/new"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# ── extract notify() (from 'notify() {' to first line that is exactly 8sp+}) ──
# (Nix interpolations resolved with test values so the shell stays valid)
awk '/^        notify\(\) \{/{f=1} f{print} f&&/^        \}$/{exit}' "$MOD" | sed -e 's/^        //' -e 's|\${cfg.notifyIcon}|nix-snowflake-white|' -e 's|\${toString cfg.notifyTimeout}|10000|' > "$T/notify.func"
grep -q '^notify() {' "$T/notify.func" && grep -q 'runuser' "$T/notify.func" \
  && ok "notify() extracted intact" || ko "notify() extraction broken"

# ── extract reboot block, resolving the Nix bool interpolation ──
awk '/^        NEW_SYSTEM=/{f=1} f{print} f&&/^        fi$/{c++; if(c==2) exit}' "$MOD" \
  | sed 's/^        //; s/\${lib.boolToString cfg.allowReboot}/__ALLOW__/' > "$T/reboot.tpl"
grep -q '__ALLOW__' "$T/reboot.tpl" && ok "reboot block extracted" || ko "reboot extraction broken"

# ── stubs ──
cat > "$T/fakebin/loginctl" <<'EOF'
#!/usr/bin/env bash
# SCENARIO env controls output. Args: list-sessions | show-session <s> -p <k>
case "$SCENARIO" in
  none) [[ "$1" == "list-sessions" ]] && exit 0; echo "N/A";;
  user) case "$1" in
    list-sessions) echo "3 1000 minegame seat0";;
    show-session) case "$4" in
      Type) echo "wayland";; Active) echo "yes";; Name) echo "minegame";; esac;;
  esac;;
  gdm) case "$1" in
    list-sessions) echo "1 120 gdm seat0";;
    show-session) case "$4" in
      Type) echo "x11";; Active) echo "yes";; Name) echo "gdm";; esac;;
  esac;;
esac
EOF
cat > "$T/fakebin/id" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-u" && "$2" == "minegame" ]] && echo 1000 || exit 1
EOF
cat > "$T/fakebin/runuser" <<'EOF'
#!/usr/bin/env bash
echo "RUNUSER: $*" >> "$CALLS"
exit 0
EOF
chmod +x "$T/fakebin/"*
export PATH="$T/fakebin:$PATH"
export CALLS="$T/calls.log"

run_notify(){
  local scenario="$1" notif="$2"
  : > "$CALLS"
  SCENARIO="$scenario" AUTO_UPDATE_NOTIFY="$notif" bash -c "
    log() { :; }
    source \"$T/notify.func\"
    notify normal 't' 'b'
  " 2>/dev/null
}

# ── notify cases ──
run_notify user 1
grep -q 'RUNUSER:.*-u minegame.*notify-send' "$CALLS" \
  && ok "active wayland user → notify-send via runuser" || ko "active user not notified"
grep -q 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus' "$CALLS" \
  && ok "dbus env targets user bus" || ko "dbus env wrong"
grep -q 'notify-send -i ' "$CALLS" \
  && ok "notification carries an icon" || ko "notification icon missing"
grep -q 'notify-send .* -t 10000' "$CALLS" \
  && ok "notification carries a timeout" || ko "notification timeout missing"

run_notify none 1
[[ ! -s "$CALLS" ]] && ok "no session → silent (journal only)" || ko "notified with no session"

run_notify gdm 1
[[ ! -s "$CALLS" ]] && ok "gdm greeter session ignored" || ko "gdm was notified"

run_notify user 0
[[ ! -s "$CALLS" ]] && ok "notify disabled → silent" || ko "notified while disabled"

# ── extract note_once (pure shell, no Nix interpolation to resolve) ──
awk '/^        note_once\(\) \{/{f=1} f{print} f&&/^        \}$/{exit}' "$MOD" | sed 's/^        //' > "$T/note_once.func"
grep -q '^note_once() {' "$T/note_once.func" \
  && ok "note_once() extracted intact" || ko "note_once() extraction broken"

run_note(){
  local last="$1" sys="$2"
  : > "$CALLS"; rm -f "$T/state"; [[ -n "$last" ]] && echo "$last" > "$T/state"
  bash -c "
    log() { echo \"LOG: \$*\"; }
    notify() { echo \"NOTIFY: \$*\" >> \"$CALLS\"; }
    STATE_FILE=\"$T/state\"
    last_notified=\$(cat \"\$STATE_FILE\" 2>/dev/null || true)
    source \"$T/note_once.func\"
    note_once \"$sys\" normal 't' 'b'
  " > "$T/note.out" 2>&1
}

# ── dedup cases ──
run_note "" "/sys-A"
grep -q 'NOTIFY' "$CALLS" && [[ "$(cat "$T/state")" == "/sys-A" ]] \
  && ok "first sight of generation → notify + state stored" || ko "first sight failed"

run_note "/sys-A" "/sys-A"
! grep -q 'NOTIFY' "$CALLS" && grep -q 'already notified, silent' "$T/note.out" \
  && ok "unchanged generation → silent, journal only" || ko "spam on unchanged generation"

run_note "/sys-A" "/sys-B"
grep -q 'NOTIFY' "$CALLS" && [[ "$(cat "$T/state")" == "/sys-B" ]] \
  && ok "new generation → notify + state updated" || ko "new generation not notified"

# ── extract check_health (resolve Nix interpolations with test values) ──
awk '/^        check_health\(\) \{/{f=1} f{print} f&&/^        \}$/{exit}' "$MOD" \
  | sed -e 's/^        //' \
        -e 's|\${lib.escapeShellArgs cfg.healthCheck.units}|sshd.service cron.service|' \
        -e 's|\${lib.boolToString cfg.healthCheck.requireNetwork}|true|' \
        -e 's|\${lib.boolToString cfg.healthCheck.checkFailedUnits}|true|' \
        -e "s|''\\\${PROC_NET_ROUTE:-/proc/net/route}|\${PROC_NET_ROUTE}|" > "$T/check_health.func"
grep -q '^check_health() {' "$T/check_health.func" \
  && ok "check_health() extracted intact" || ko "check_health() extraction broken"

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
    bash -c "log() { echo \"LOG: \$*\"; }; source \"$T/check_health.func\"; check_health" > "$T/health.out" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  HRc=$rc
}

# ── health cases ──
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

# ── reboot cases (fake trees) ──
mk_tree(){ mkdir -p "$T/trees/$1"; echo "kernel-$2" > "$T/trees/$1/kernel"; echo "init-$2" > "$T/trees/$1/init"; }
run_reboot(){
  local allow="$1" newdir="$2"
  mk_tree booted same; mk_tree new new
  echo "init-new" > "$T/trees/new/init"
  sed -e "s/__ALLOW__/$allow/" \
      -e 's|^NEW_SYSTEM=.*|NEW_SYSTEM="'"$newdir"'"|' \
      -e 's|^BOOTED_SYSTEM=.*|BOOTED_SYSTEM="'"$T/trees/booted"'"|' \
      "$T/reboot.tpl" > "$T/reboot.body"
  # Reboot paths now go through the real note_once (module uses it):
  # stub log/notify/state around it, like the notify tests do.
  { echo 'log(){ :; }'
    echo 'notify(){ echo "NOTIFY: $*"; }'
    echo "STATE_FILE=\"$T/rstate\""
    echo 'last_notified=""'
    cat "$T/note_once.func"
    cat "$T/reboot.body"; } > "$T/reboot.sh"
  BOOTED_SYSTEM="$T/trees/booted" NEW_SYSTEM="$T/trees/new" bash "$T/reboot.sh" 2>&1
}
cat > "$T/fakebin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "SYSTEMCTL: $*" >> "$CALLS"
EOF
chmod +x "$T/fakebin/systemctl"

: > "$CALLS"
out=$(run_reboot true "$T/trees/new")
grep -q 'SYSTEMCTL: reboot' "$CALLS" \
  && ok "kernel+init changed, allowReboot → reboot" || ko "no reboot when expected ($out)"

: > "$CALLS"
out=$(run_reboot false "$T/trees/new")
grep -q 'reboot required' <<<"$out" && ! grep -q 'SYSTEMCTL: reboot' "$CALLS" \
  && ok "changed, no allowReboot → notice, no reboot" || ko "wrong no-reboot path ($out)"

: > "$CALLS"
out=$(run_reboot true "$T/trees/booted")
grep -q 'already up to date' <<<"$out" && ! grep -q 'SYSTEMCTL' "$CALLS" \
  && ok "identical generations → up-to-date, nothing staged" || ko "wrong up-to-date path ($out)"

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
