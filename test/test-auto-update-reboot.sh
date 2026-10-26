#!/usr/bin/env bash
### Tests the reboot countdown (_await_reboot_window from services.nix):
### expiry proceeds, a cancel marker aborts and is consumed, and
### the wait happens in 1-minute slices. The function comes verbatim via
### test/lib-fragments.sh; sleep is stubbed so the suite runs instantly.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-fragments.sh
source "$REPO/test/lib-fragments.sh"
T=/tmp/opencode/reboot-test
rm -rf "$T"; mkdir -p "$T"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

fragment services.nix reboot-countdown > "$T/reboot.func"
grep -q '_await_reboot_window() {' "$T/reboot.func" \
  && ok "reboot-countdown extracted intact" || ko "reboot-countdown extraction broken"

# ── _needs_reboot: boot-critical files, including initrd ──
fragment services.nix reboot-needed > "$T/need.func"
grep -q '_needs_reboot() {' "$T/need.func" \
  && ok "reboot-needed extracted intact" || ko "reboot-needed extraction broken"

run_need(){
  local mut="$1" want="$2" desc="$3"
  local b="$T/need-booted-$pass-$fail" n="$T/need-new-$pass-$fail"
  rm -rf "$b" "$n"; mkdir -p "$b" "$n"
  for f in kernel init initrd; do echo "base-$f" > "$b/$f"; echo "base-$f" > "$n/$f"; done
  case "$mut" in
    kernel) echo changed > "$n/kernel" ;;
    init) echo changed > "$n/init" ;;
    initrd) echo changed > "$n/initrd" ;;
    missing) rm -f "$n/initrd" ;;
  esac
  local rc=0
  if bash -c "source \"$T/need.func\"; _needs_reboot \"$b\" \"$n\"" 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi
  if [[ "$rc" == "$want" ]]; then ok "$desc (rc=$rc)"; else ko "$desc: got rc=$rc, want $want"; fi
}

run_need same 1 "identical kernel/init/initrd -> no reboot"
run_need kernel 0 "kernel change -> reboot"
run_need init 0 "init change -> reboot"
run_need initrd 0 "initrd-only change -> reboot (regression)"
run_need missing 0 "missing boot file -> reboot"

# run_case <delay> <precreate:0|fresh|stale> <create_at_tick:0=never> <want_rc> <want_ticks> <desc>
# CREATE_AT>0: the stubbed sleep creates the marker once ticks reach it.
# Only markers created during the window count: stale ones are dropped.
run_case(){
  local delay="$1" precreate="$2" create_at="$3" want_rc="$4" want_ticks="$5" desc="$6"
  local marker="$T/marker-$pass-$fail"
  rm -f -- "$marker"
  [[ "$precreate" == "fresh" ]] && touch "$marker"
  [[ "$precreate" == "stale" ]] && touch -d '2 hours ago' "$marker"
  local rc=0 ticks=0
  # Window start an hour back: fresh/mid-window markers qualify, the
  # 2-hours-old stale one does not. Mirrors production, where the
  # caller timestamps before announcing the deadline.
  local start=$(( $(date +%s) - 3600 ))
  if MARKER="$marker" CREATE_AT="$create_at" CALLS="$T/ticks.log" bash -c "
    set -euo pipefail
    _status() { :; }
    sleep() { echo tick >> \"\$CALLS\"; if (( CREATE_AT > 0 )) && (( \$(wc -l < \"\$CALLS\") >= CREATE_AT )); then touch \"\$MARKER\"; fi; }
    source \"$T/reboot.func\"
    _await_reboot_window \"$delay\" \"\$MARKER\" \"$start\"
  " 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi
  ticks=$(wc -l < "$T/ticks.log" 2>/dev/null || echo 0)
  : > "$T/ticks.log"
  if [[ "$rc" == "$want_rc" && "$ticks" == "$want_ticks" ]]; then
    if [[ -e "$marker" ]]; then
      ko "$desc: marker left behind (must be consumed or cleaned)"
    else
      ok "$desc (rc=$rc, ${ticks} slices)"
    fi
  else
    ko "$desc: got rc=$rc/${ticks} slices, want rc=$want_rc/${want_ticks} slices"
  fi
}
: > "$T/ticks.log"

run_case 3 0 0 0 3 "no marker -> window expires, reboot proceeds"
run_case 60 fresh 0 1 1 "fresh marker -> cancelled at first check, marker consumed"
run_case 60 stale 0 0 60 "stale marker -> ignored and cleaned, reboot proceeds"
run_case 60 0 2 1 2 "marker mid-window -> cancelled when seen, marker consumed"
run_case 0 0 0 0 0 "zero delay edge -> immediate expiry, no sleep"

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
