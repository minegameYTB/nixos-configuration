#!/usr/bin/env bash
### Tests the channel synchronisation with REAL git:
### origin (bare, branch `flake`) + fixture commits/tags. Remote resolve goes
### through a shimmed `git ls-remote` (FAKE_REV) to stay offline; fetch/clone/
### reset/clean/gc exercise the real git binary against the local bare origin.
### The tested functions come verbatim from sync.nix via lib-fragments.sh.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-fragments.sh
source "$REPO/test/lib-fragments.sh"
T=/tmp/opencode/checkout-test
rm -rf "$T"; mkdir -p "$T/fakebin"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# ── extract sync fragment, resolving Nix interpolations with test values ──
fragment sync.nix sync > "$T/sync.raw"
sed -e 's|\${cfg.channel}|flake|g' \
    -e 's|\${channel}|flake|g' \
    -e 's|\${cfg.flakeRef}|REMOTE-REF|g' \
    -e 's|\${cfg.configuration}|testconf|g' \
    -e "s|''\\\${AUTO_UPDATE_GIT_URL:-\${repo.gitUrl}}|\${AUTO_UPDATE_GIT_URL}|" \
    -e "s|''\\\${[0-9a-zA-Z_]*:-[^}]*}|\${IGNORED}|g" \
    -e 's|\${cfg.timeouts.[a-zA-Z]*}|5m|g' \
    -e 's|\${toString cfg.minDiskGB}|10|g' \
    -e 's|\${toString cfg.timeouts.internetWait}|600|g' \
  "$T/sync.raw" > "$T/sync.func"
grep -q '_sync_channel_clone() {' "$T/sync.func" && grep -q '_force_sync_mirror' "$T/sync.func" \
  && grep -q -- '--no-tags' "$T/sync.func" \
  && ! grep -Eq '\$\{(cfg|repo|lib)\.' "$T/sync.func" \
  && ok "sync fragment extracted intact (+ --no-tags)" || ko "extraction broken"

# ── stubs: git ls-remote shim (rest delegated to real git), sleep ──
REALGIT=$(command -v git)
cat > "$T/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" ]]; then
  if [[ -n "\$FAKE_REV" ]]; then
    printf '%s\trefs/heads/flake\n' "\$FAKE_REV"
  fi
  echo "GIT-LSREMOTE: \$*" >> "\$CALLS"
  exit 0
fi
exec "$REALGIT" "\$@"
EOF
cat > "$T/fakebin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$T/fakebin/"*
export PATH="$T/fakebin:$PATH"
export CALLS="$T/calls.log"

driver(){
  cat <<EOF
set -euo pipefail
_status() { echo "[sync] \$*"; }
_fail() { echo "[sync] ERROR(\$1)"; exit 1; }
_err_lookup() { echo "lookup:\$1/\$2"; }
_filter_git_progress() { cat; }
_monitor_nix_output() { cat; }
WORKDIR="$T/work-$CASE"
mkdir -p "\$WORKDIR"
FLAKE="REMOTE-REF"
SRC_ID=""
AUTO_UPDATE_NIX_LOG_FORMAT="raw"
EOF
  cat "$T/sync.func"
  echo '_sync_channel_clone'
  echo 'echo "FINAL-FLAKE=$FLAKE FINAL-SRC=$SRC_ID"'
}

run_case(){ CASE="$1"; : > "$CALLS"; bash <(driver) > "$T/out-$1.log" 2>&1; echo "rc=$?"; }

# ── git fixture: origin (bare) + seed on branch `flake`, plus a tag ──
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q --bare "$T/origin.git"
git init -q -b flake "$T/seed" && printf '{ outputs = { ... }: { };\n}\n' > "$T/seed/flake.nix" \
  && echo '{"nodes":{}}' > "$T/seed/flake.lock" \
  && git -C "$T/seed" add -A && git -C "$T/seed" commit -qm v1 \
  && git -C "$T/seed" tag v99 && git -C "$T/seed" push -q "$T/origin.git" flake v99
V1=$(git --git-dir="$T/origin.git" rev-parse flake)
# file:// so --depth/--no-tags are honored (plain local paths ignore --depth).
export AUTO_UPDATE_GIT_URL="file://$T/origin.git"

# ── A: no clone → fresh --depth 1 --no-tags clone ──
export FAKE_REV="$V1"
rc=$(run_case A)
if grep -q "FINAL-FLAKE=$T/work-A/flake FINAL-SRC=$V1" "$T/out-A.log" \
   && git -C "$T/work-A/flake" rev-parse --is-shallow-repository | grep -q true \
   && [[ -z "$(git -C "$T/work-A/flake" tag)" ]]; then
  ok "fresh clone: shallow, at channel rev, no tags ($rc)"
else
  ko "case A ($rc): $(cat "$T/out-A.log")"
fi

# ── B: same rev → reuse, no fetch/clone ──
mkdir -p "$T/work-B"; cp -a "$T/work-A/flake" "$T/work-B/flake"
rc=$(run_case B)
if grep -q "reusing previous clone" "$T/out-B.log" \
   && grep -q "FINAL-SRC=$V1" "$T/out-B.log"; then
  ok "same rev: clone reused ($rc)"
else
  ko "case B ($rc): $(cat "$T/out-B.log")"
fi

# ── advance origin linearly (v2) ──
printf 'x = 1;\n' > "$T/seed/extra.nix" && git -C "$T/seed" add -A \
  && git -C "$T/seed" commit -qm v2 && git -C "$T/seed" push -q "$T/origin.git" flake
V2=$(git --git-dir="$T/origin.git" rev-parse flake)

# ── C: linear advance → incremental force-sync (no re-clone) ──
mkdir -p "$T/work-C"; cp -a "$T/work-A/flake" "$T/work-C/flake"
export FAKE_REV="$V2"
rc=$(run_case C)
if grep -q "Force-syncing channel @ $V2" "$T/out-C.log" \
   && ! grep -q "Cloning channel" "$T/out-C.log" \
   && [[ "$(git -C "$T/work-C/flake" rev-parse HEAD)" == "$V2" ]] \
   && git -C "$T/work-C/flake" rev-parse --is-shallow-repository | grep -q true; then
  ok "linear advance: incremental force-sync, still shallow ($rc)"
else
  ko "case C ($rc): $(cat "$T/out-C.log")"
fi

# ── force-move origin backwards (pointer-style non-ff) ──
# NOTE: both commands need -C: without it the push would run in the real
# repo (CWD) and push its own `flake` branch into the fixture.
git -C "$T/seed" reset -q --hard "$V1" && git -C "$T/seed" push -q --force "$T/origin.git" flake
export FAKE_REV="$V1"

# ── D: force-move → followed via fetch --force + reset ──
mkdir -p "$T/work-D"; cp -a "$T/work-C/flake" "$T/work-D/flake"
rc=$(run_case D)
if grep -q "Force-syncing channel @ $V1" "$T/out-D.log" \
   && [[ "$(git -C "$T/work-D/flake" rev-parse HEAD)" == "$V1" ]]; then
  ok "force-move: mirror follows non-ff pointer ($rc)"
else
  ko "case D ($rc): $(cat "$T/out-D.log")"
fi

# ── E: corrupt clone (no .git) → fresh clone fallback ──
mkdir -p "$T/work-E"; cp -a "$T/work-D/flake" "$T/work-E/flake"
rm -rf "$T/work-E/flake/.git"
rc=$(run_case E)
if grep -q "Cloning channel @ $V1" "$T/out-E.log" \
   && [[ "$(git -C "$T/work-E/flake" rev-parse HEAD)" == "$V1" ]]; then
  ok "corrupt clone: fresh clone fallback ($rc)"
else
  ko "case E ($rc): $(cat "$T/out-E.log")"
fi

# ── F: unresolvable channel → _fail channel-resolve ──
export FAKE_REV=""
rc=$(run_case F)
if [[ "$rc" != "rc=0" ]] && grep -q "ERROR(channel-resolve)" "$T/out-F.log"; then
  ok "empty ls-remote → fail channel-resolve ($rc)"
else
  ko "case F ($rc): $(cat "$T/out-F.log")"
fi
export FAKE_REV="$V1"

# ── I/J/K: _nvd_diff_profile generation resolution (report-changes style) ──
# Faithful profile layout: `system` -> `system-<current>-link`, siblings
# `system-<N>-link` (string concat `$profile-$N-link` must resolve).
mkdir -p "$T/prof" "$T/sys-old" "$T/sys-new"
ln -sfn "$T/sys-old" "$T/prof/system-10-link"
ln -sfn "$T/sys-new" "$T/prof/system-11-link"
ln -sfn "$T/prof/system-11-link" "$T/prof/system"
cat > "$T/fakebin/nix-env" <<'EOF'
#!/usr/bin/env bash
# canned `nix-env --list-generations -p <profile>` from $NIXENV_OUT
cat "$NIXENV_OUT"
EOF
cat > "$T/fakebin/nvd" <<'EOF'
#!/usr/bin/env bash
echo "NVD: $*" >> "$CALLS"
exit 0
EOF
chmod +x "$T/fakebin/nix-env" "$T/fakebin/nvd"
export NIXENV_OUT="$T/list-generations.txt"

nvd_driver(){
  cat <<EOF
set -euo pipefail
_status() { echo "[sync] \$*"; }
_fail() { echo "[sync] ERROR(\$1)"; exit 1; }
_prefix_lines() { cat; }
INTERACTIVE_OUTPUT=0
SYSTEM_PROFILE="$T/prof/system"
EOF
  grep -A60 '_nvd_diff_profile() {' "$T/sync.func" | awk '/_nvd_diff_profile\(\) \{/{f=1} f{print} f&&/^  \}$/{exit}'
  echo '_nvd_diff_profile'
}

# I: previous generation resolved, nvd called old -> new in order
printf '  10   2026-01-01 00:00:00\n  11   2026-01-02 00:00:00 (current)\n' > "$T/list-generations.txt"
: > "$CALLS"
if bash <(nvd_driver) > "$T/out-I.log" 2>&1; then
  grep -q "NVD: diff $T/sys-old $T/sys-new" "$CALLS" \
    && ok "nvd diff resolves previous generation, old -> new order" || ko "case I: $(cat "$CALLS") // $(cat "$T/out-I.log")"
else
  ko "case I rc!=0: $(cat "$T/out-I.log")"
fi

# J: single generation (no previous) -> skip, no nvd
printf '  11   2026-01-02 00:00:00 (current)\n' > "$T/list-generations.txt"
: > "$CALLS"
if bash <(nvd_driver) > "$T/out-J.log" 2>&1; then
  ! grep -q "NVD:" "$CALLS" && grep -q "No previous generation" "$T/out-J.log" \
    && ok "no previous generation -> skip without nvd" || ko "case J: $(cat "$CALLS") // $(cat "$T/out-J.log")"
else
  ko "case J rc!=0: $(cat "$T/out-J.log")"
fi

# K: staged == previous -> skip, no nvd
printf '  10   2026-01-01 00:00:00\n  11   2026-01-02 00:00:00 (current)\n' > "$T/list-generations.txt"
ln -sfn "$T/sys-old" "$T/prof/system-11-link"
: > "$CALLS"
if bash <(nvd_driver) > "$T/out-K.log" 2>&1; then
  ! grep -q "NVD:" "$CALLS" && grep -q "no package changes" "$T/out-K.log" \
    && ok "identical systems -> skip without nvd" || ko "case K: $(cat "$CALLS") // $(cat "$T/out-K.log")"
else
  ko "case K rc!=0: $(cat "$T/out-K.log")"
fi
ln -sfn "$T/sys-new" "$T/prof/system-11-link"
cat > "$T/fakebin/nix" <<'EOF'
#!/usr/bin/env bash
n=$(cat "$NIX_COUNT" 2>/dev/null || echo 0)
n=$((n+1)); echo "$n" > "$NIX_COUNT"
echo "NIX-TRY-$n: $*" >> "$CALLS"
(( n < 3 )) && exit 1 || exit 0
EOF
chmod +x "$T/fakebin/nix"
export NIX_COUNT="$T/nixcount"
echo 0 > "$NIX_COUNT"
if bash -c "
  set -euo pipefail
  _status() { echo \"[sync] \$*\"; }
  _fail() { echo \"[sync] ERROR(\$1)\"; exit 1; }
  FLAKE=/tmp; AUTO_UPDATE_NIX_LOG_FORMAT=raw
  _filter_git_progress() { cat; }
  _monitor_nix_output() { cat; }
  _prefix_lines() { cat; }
  source \"$T/sync.func\"
  _update_flake_inputs
" > "$T/out-G.log" 2>&1; then
  if [[ "$(cat "$T/nixcount")" -eq 3 ]] && grep -q "attempt 3/3" "$T/out-G.log"; then
    ok "flake inputs: retry then success on 3rd try"
  else
    ko "case G: unexpected attempts ($(cat "$T/nixcount"))"
  fi
else
  ko "case G: $(cat "$T/out-G.log")"
fi

# ── H: flake inputs always failing → _fail flake-update ──
cat > "$T/fakebin/nix" <<'EOF'
#!/usr/bin/env bash
echo "NIX: $*" >> "$CALLS"
exit 1
EOF
chmod +x "$T/fakebin/nix"
if bash -c "
  set -euo pipefail
  _status() { echo \"[sync] \$*\"; }
  _fail() { echo \"[sync] ERROR(\$1)\"; exit 1; }
  FLAKE=/tmp; AUTO_UPDATE_NIX_LOG_FORMAT=raw
  _filter_git_progress() { cat; }
  _monitor_nix_output() { cat; }
  _prefix_lines() { cat; }
  source \"$T/sync.func\"
  _update_flake_inputs
" > "$T/out-H.log" 2>&1; then
  ko "case H: expected failure, got success"
else
  grep -q "ERROR(flake-update)" "$T/out-H.log" \
    && ok "flake inputs: persistent failure → fail flake-update" || ko "case H: $(cat "$T/out-H.log")"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
