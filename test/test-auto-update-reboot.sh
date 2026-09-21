#!/usr/bin/env bash
### Tests the reboot countdown (_await_reboot_window from services.nix):
### expiry proceeds, a postponement marker aborts and is consumed, and
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
run_case 60 fresh 0 1 1 "fresh marker -> postponed at first check, marker consumed"
run_case 60 stale 0 0 60 "stale marker -> ignored and cleaned, reboot proceeds"
run_case 60 0 2 1 2 "marker mid-window -> postponed when seen, marker consumed"
run_case 0 0 0 0 0 "zero delay edge -> immediate expiry, no sleep"

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
