#!/usr/bin/env bash
### Tests the service's source-selection with REAL git:
### origin (bare, branch `flake`) + clone. Remote fetch goes through real
### `git clone --depth 1` (offline-safe vs the local bare origin); only
### `ls-remote` is shimmed (FAKE_REV) to avoid touching github.com, and
### nix/nixos-rebuild are stubbed (rebuild needs NixOS).
### The tested block is extracted from modules/misc/auto-update.nix.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="$REPO/configurations/modules/misc/auto-update.nix"
T=/tmp/opencode/checkout-test
rm -rf "$T"; mkdir -p "$T/fakebin"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# ── extract source-selection + remote/update/rebuild blocks (marker-based) ──
{ awk '/CHECKOUT="/{f=1} f{print} f&&/^ *..}$/{exit}' "$MOD"
  awk '/--- remote mode/{f=1} f{print} f&&/fail "nixos-rebuild boot failed"/{exit}' "$MOD"; } \
  | sed -e '/\${lib.optionalString/d' -e "/^ *''}$/d" \
        -e "s|\${cfg.localCheckout}|$T/checkout|g" \
        -e 's|\${cfg.channel}|flake|g' \
        -e 's|\${cfg.flakeRef}|REMOTE-REF|g' \
        -e 's|\${cfg.configuration}|testconf|g' \
        -e "s|''\\\${AUTO_UPDATE_GIT_URL:-https://github.com/\\\${repoSlug}.git}|\${AUTO_UPDATE_GIT_URL}|" \
        -e 's/^        //' > "$T/source.func"
grep -q 'pull --ff-only' "$T/source.func" && grep -q 'nixos-rebuild boot' "$T/source.func" \
  && grep -q 'git clone --depth 1' "$T/source.func" \
  && ok "source block extracted intact" || ko "extraction broken"

# ── stubs: git ls-remote shim (rest delegated to real git), nix, rebuild ──
REALGIT=$(command -v git)
cat > "$T/fakebin/git" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "ls-remote" ]]; then
  printf '%s\trefs/heads/flake\n' "\$FAKE_REV"
  echo "GIT-LSREMOTE: \$*" >> "\$CALLS"
  exit 0
fi
exec "$REALGIT" "\$@"
EOF
cat > "$T/fakebin/nix" <<'EOF'
#!/usr/bin/env bash
echo "NIX: $*" >> "$CALLS"
exit 0
EOF
cat > "$T/fakebin/nixos-rebuild" <<'EOF'
#!/usr/bin/env bash
echo "NRB: $*" >> "$CALLS"
exit 0
EOF
chmod +x "$T/fakebin/"*
export PATH="$T/fakebin:$PATH"
export CALLS="$T/calls.log"

driver(){
  cat <<EOF
log() { echo "[auto-update] \$*"; }
fail() { echo "[auto-update] ERROR: \$*"; exit 1; }
notify() { echo "NOTIFY: \$*"; }
WORKDIR="$T/work-$CASE"
mkdir -p "\$WORKDIR"
FLAKE="REMOTE-REF"
EOF
  cat "$T/source.func"
  echo 'echo "FINAL-FLAKE=$FLAKE"'
}

run_case(){ CASE="$1"; : > "$CALLS"; bash <(driver) > "$T/out-$1.log" 2>&1; echo "rc=$?"; }

# ── git fixture: origin (bare) + checkout on branch `flake` ──
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q --bare "$T/origin.git"
git init -q -b flake "$T/seed" && printf '{ outputs = { ... }: { };\n}\n' > "$T/seed/flake.nix" \
  && echo '{"nodes":{}}' > "$T/seed/flake.lock" \
  && git -C "$T/seed" add -A && git -C "$T/seed" commit -qm v1 \
  && git -C "$T/seed" push -q "$T/origin.git" flake
git clone -q -b flake "$T/origin.git" "$T/checkout"
export AUTO_UPDATE_GIT_URL="$T/origin.git"

# ── A: clean checkout behind origin → pull + rebuild ON the checkout ──
export FAKE_REV=revREMOTE
printf 'x = 1;\n' > "$T/seed/extra.nix" && git -C "$T/seed" add -A \
  && git -C "$T/seed" commit -qm v2 && git -C "$T/seed" push -q "$T/origin.git" flake
rc=$(run_case A)
if grep -q "FINAL-FLAKE=$T/checkout" "$T/out-A.log" \
   && grep -q "NRB: boot --flake $T/checkout#testconf" "$CALLS" \
   && ! grep -q "cloning channel" "$T/out-A.log"; then
  ok "behind origin: pull + rebuild à la volée sur le checkout ($rc)"
else
  ko "case A ($rc): $(cat "$T/out-A.log") // $(cat "$CALLS")"
fi

# ── B: dirty checkout → fallback remote (fresh clone) ──
echo "# hack" >> "$T/checkout/flake.nix"
rc=$(run_case B)
if grep -q "FINAL-FLAKE=$T/work-B/flake" "$T/out-B.log" \
   && grep -q "cloning channel @ revREMOTE" "$T/out-B.log" \
   && grep -q "NRB: boot --flake $T/work-B/flake#testconf" "$CALLS"; then
  ok "dirty checkout: fallback remote, rebuild sur clone ($rc)"
else
  ko "case B ($rc): $(cat "$T/out-B.log") // $(cat "$CALLS")"
fi
git -C "$T/checkout" checkout -q -- flake.nix

# ── C: wrong branch → fallback remote ──
git -C "$T/checkout" checkout -qb main
rc=$(run_case C)
if grep -q "FINAL-FLAKE=$T/work-C/flake" "$T/out-C.log" && grep -q "not on flake" "$T/out-C.log"; then
  ok "wrong branch: fallback remote ($rc)"
else
  ko "case C ($rc): $(cat "$T/out-C.log")"
fi
git -C "$T/checkout" checkout -q flake

# ── D: diverged (local commit + remote advance) → pull --ff-only fails → fallback ──
echo "# local" >> "$T/checkout/flake.nix" && git -C "$T/checkout" commit -qam local \
  && printf 'y = 2;\n' > "$T/seed/extra2.nix" && git -C "$T/seed" add -A \
  && git -C "$T/seed" commit -qm v3 && git -C "$T/seed" push -q "$T/origin.git" flake
rc=$(run_case D)
if grep -q "FINAL-FLAKE=$T/work-D/flake" "$T/out-D.log" && grep -q "pull failed" "$T/out-D.log"; then
  ok "diverged: pull --ff-only refused, fallback remote ($rc)"
else
  ko "case D ($rc): $(cat "$T/out-D.log")"
fi

# ── R: clone already at channel rev → reuse, no re-clone ──
export FAKE_REV
FAKE_REV=$(git --git-dir="$T/origin.git" rev-parse flake)
git clone -q "$T/origin.git" "$T/work-R/flake" 2>/dev/null || { mkdir -p "$T/work-R"; git clone -q "$T/origin.git" "$T/work-R/flake"; }
git -C "$T/work-R/flake" checkout -q flake
rc=$(run_case R)
if grep -q "reusing previous clone" "$T/out-R.log" \
   && grep -q "FINAL-FLAKE=$T/work-R/flake" "$T/out-R.log" \
   && ! grep -q "Clonage dans" "$T/out-R.log" \
   && grep -q "NRB: boot --flake $T/work-R/flake#testconf" "$CALLS"; then
  ok "same rev: clone reused, rebuild proceeds ($rc)"
else
  ko "case R ($rc): $(cat "$T/out-R.log") // $(cat "$CALLS")"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
