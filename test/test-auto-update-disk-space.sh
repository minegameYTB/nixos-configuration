#!/usr/bin/env bash
### Tests the disk pre-checks in sync.nix (_check_disk_space on /nix/store,
### _check_boot_space on /boot): pass above threshold, _fail with the right
### CODE below it. Functions come verbatim from sync.nix via lib-fragments.sh.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-fragments.sh
source "$REPO/test/lib-fragments.sh"
T=/tmp/opencode/disk-space-test
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
    -e 's|\${toString cfg.minBootMB}|500|g' \
    -e 's|\${toString cfg.timeouts.internetWait}|600|g' \
    -e 's|\${toString cfg.buildMaxAttempts}|3|g' \
    -e 's|\${toString cfg.buildRetryDelaySeconds}|60|g' \
    -e "s|''\\\${AUTO_UPDATE_GIT_URL:-\${repo.gitUrl}}|\${AUTO_UPDATE_GIT_URL}|" \
  "$T/sync.raw" > "$T/sync.func"
sed -i "s|''\\\${|\${|g" "$T/sync.func"
grep -q '_check_disk_space() {' "$T/sync.func" && grep -q '_check_boot_space() {' "$T/sync.func" \
  && ! grep -Eq '\$\{(cfg|repo|lib)\.' "$T/sync.func" \
  && ok "sync fragment extracted intact (+ boot-space check)" || ko "extraction broken"

# ── stub df: canned Available (1K blocks) per mountpoint ──
cat > "$T/fakebin/df" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "/nix/store" ]]; then avail="$DF_STORE_KB"; else avail="$DF_BOOT_KB"; fi
printf 'Filesystem 1K-blocks Used Available Use%% Mounted on\n/dev/fake 100000000 50000000 %s 50%% %s\n' "$avail" "$1"
EOF
chmod +x "$T/fakebin/df"
export PATH="$T/fakebin:$PATH"

driver(){
  cat <<EOF
set -euo pipefail
_status() { echo "[disk] \$*"; }
_fail() { echo "[disk] ERROR(\$1:\$2)"; exit 1; }
EOF
  cat "$T/sync.func"
  echo '_check_disk_space'
  echo '_check_boot_space'
}

# run_case <store-MB> <boot-MB> — df wants 1K blocks
run_case(){
  export DF_STORE_KB=$(( $1 * 1024 )) DF_BOOT_KB=$(( $2 * 1024 ))
  if bash <(driver) > "$T/out.log" 2>&1; then
    echo "rc=0"
  else
    echo "rc=$?"
  fi
}

# ── 1: plenty of space on both → green ──
rc=$(run_case 57344 800)
if [[ "$rc" == "rc=0" ]] && grep -q "Disk space OK" "$T/out.log" && grep -q "Boot space OK" "$T/out.log"; then
  ok "56G store + 800M boot → both checks pass ($rc)"
else
  ko "case roomy ($rc): $(cat "$T/out.log")"
fi

# ── 2: store below 10G → fail disk-space before even checking boot ──
rc=$(run_case 5120 800)
if [[ "$rc" != "rc=0" ]] && grep -q "ERROR(disk-space:" "$T/out.log" \
  && ! grep -q "Boot space" "$T/out.log"; then
  ok "5G store → fail disk-space, boot unchecked ($rc)"
else
  ko "case store-low ($rc): $(cat "$T/out.log")"
fi

# ── 3: boot below 500M (the hp-240 ESP incident) → fail boot-space ──
rc=$(run_case 57344 100)
if [[ "$rc" != "rc=0" ]] && grep -q "Disk space OK" "$T/out.log" \
  && grep -q "ERROR(boot-space:" "$T/out.log"; then
  ok "100M boot → fail boot-space after store OK ($rc)"
else
  ko "case boot-low ($rc): $(cat "$T/out.log")"
fi

# ── 4: exactly at thresholds → pass (strict < comparison) ──
rc=$(run_case 10240 500)
if [[ "$rc" == "rc=0" ]]; then
  ok "exactly 10G/500M → pass ($rc)"
else
  ko "case boundary ($rc): $(cat "$T/out.log")"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
