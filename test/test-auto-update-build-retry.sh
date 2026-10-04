#!/usr/bin/env bash
### Tests the in-memory build retry loop in sync.nix (_run_nixos_build):
### pure build (no profile mutation) retried up to buildMaxAttempts with
### a sleep between attempts; final failure returns 1 for _fail rebuild-boot.
### Functions come verbatim from sync.nix via lib-fragments.sh.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-fragments.sh
source "$REPO/test/lib-fragments.sh"
T=/tmp/opencode/build-retry-test
rm -rf "$T"; mkdir -p "$T/fakebin"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# ── extract sync fragment, resolving Nix interpolations with test values ──
fragment sync.nix sync > "$T/sync.raw"
sed -e 's|\${cfg.channel}|flake|g' \
    -e 's|\${channel}|flake|g' \
    -e 's|\${cfg.configuration}|testconf|g' \
    -e 's|\${cfg.timeouts.build}|5m|g' \
    -e 's|\${cfg.timeouts.boot}|5m|g' \
    -e 's|\${cfg.timeouts.fetch}|5m|g' \
    -e 's|\${cfg.timeouts.clone}|5m|g' \
    -e 's|\${cfg.timeouts.lsRemote}|5m|g' \
    -e 's|\${toString cfg.minDiskGB}|10|g' \
    -e 's|\${toString cfg.timeouts.internetWait}|600|g' \
    -e 's|\${toString cfg.buildMaxAttempts}|3|g' \
    -e 's|\${toString cfg.buildRetryDelaySeconds}|60|g' \
    -e "s|''\\\${AUTO_UPDATE_GIT_URL:-\${repo.gitUrl}}|\${AUTO_UPDATE_GIT_URL}|" \
  "$T/sync.raw" > "$T/sync.func"
sed -i "s|''\\\${|\${|g" "$T/sync.func"
grep -q '_run_nixos_build() {' "$T/sync.func" \
  && ! grep -Eq '\$\{(cfg|repo|lib)\.' "$T/sync.func" \
  && ok "sync fragment extracted intact (+ build retry)" || ko "extraction broken"

# Single-attempt variant (buildMaxAttempts=1 → no retry, no sleep).
sed -e 's|local build_max_attempts=3|local build_max_attempts=1|' \
  "$T/sync.func" > "$T/sync.once.func"
grep -q 'local build_max_attempts=1' "$T/sync.once.func" \
  && ok "single-attempt variant prepared" || ko "variant prep broken"

# ── stubs: nixos-rebuild fails $FAIL_LEFT times then succeeds; sleep logged ──
cat > "$T/fakebin/nixos-rebuild" <<'EOF'
#!/usr/bin/env bash
echo "REBUILD: $*" >> "$CALLS"
left=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)
if [ "$left" -gt 0 ]; then
  echo $((left - 1)) > "$FAIL_FILE"
  exit 1
fi
exit 0
EOF
cat > "$T/fakebin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "SLEEP: $*" >> "$CALLS"
exit 0
EOF
chmod +x "$T/fakebin/"*
export PATH="$T/fakebin:$PATH"
export CALLS="$T/calls.log"

driver(){
  local syncfile="$1"
  cat <<EOF
set -euo pipefail
_status() { echo "STATUS[\$1]: \$2" >> "\$CALLS"; }
_debug() { :; }
DEBUG_MODE=0
FLAKE="$T/flake"
AUTO_UPDATE_NIX_LOG_FORMAT="raw"
EOF
  cat "$syncfile"
  echo '_run_nixos_build'
}

run_case(){
  local syncfile="$1" failleft="$2"
  echo "$failleft" > "$T/fail-left"
  export FAIL_FILE="$T/fail-left"
  : > "$CALLS"
  if bash <(driver "$syncfile") > "$T/out.log" 2>&1; then
    echo "rc=0"
  else
    echo "rc=$?"
  fi
}

count(){ grep -c "$1" "$CALLS" 2>/dev/null || true; }

# ── 1: success first try → 1 build, no sleep ──
rc=$(run_case "$T/sync.func" 0)
if [[ "$rc" == "rc=0" ]] && [[ "$(count '^REBUILD:')" -eq 1 ]] && [[ "$(count '^SLEEP:')" -eq 0 ]]; then
  ok "success first try → single build, no sleep ($rc)"
else
  ko "case success-first-try ($rc): $(cat "$CALLS")"
fi

# ── 2: two transient failures then success → 3 builds, 2 sleeps of 60s ──
rc=$(run_case "$T/sync.func" 2)
if [[ "$rc" == "rc=0" ]] && [[ "$(count '^REBUILD:')" -eq 3 ]] && [[ "$(count '^SLEEP: 60$')" -eq 2 ]] \
  && grep -q 'STATUS\[WARNING\].*attempt 1/3' "$CALLS" && grep -q 'STATUS\[WARNING\].*attempt 2/3' "$CALLS"; then
  ok "two failures then success → 3 builds, 2x sleep 60 ($rc)"
else
  ko "case fail-twice ($rc): $(cat "$CALLS")"
fi

# ── 3: persistent failure → rc=1 after exactly 3 builds + 2 sleeps ──
rc=$(run_case "$T/sync.func" 9)
if [[ "$rc" != "rc=0" ]] && [[ "$(count '^REBUILD:')" -eq 3 ]] && [[ "$(count '^SLEEP:')" -eq 2 ]]; then
  ok "persistent failure → 3 attempts then give up ($rc)"
else
  ko "case persistent ($rc): $(cat "$CALLS")"
fi

# ── 4: buildMaxAttempts=1 → no retry ──
rc=$(run_case "$T/sync.once.func" 9)
if [[ "$rc" != "rc=0" ]] && [[ "$(count '^REBUILD:')" -eq 1 ]] && [[ "$(count '^SLEEP:')" -eq 0 ]]; then
  ok "maxAttempts=1 → single build, no sleep ($rc)"
else
  ko "case single-attempt ($rc): $(cat "$CALLS")"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
