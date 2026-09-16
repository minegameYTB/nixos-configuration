#!/usr/bin/env bash
### Harness: prove script/update-flake-local never invokes git,
### in both scenarios (dirty git clone, directory without .git),
### and that INSTALL_NO_GIT=1 silences checkRepoVersion.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=/tmp/opencode/gitless-test
rm -rf "$T"
mkdir -p "$T/fakebin" "$T/repo" "$T/nogit"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# ── failing git shadow: any git call aborts loudly ──
cat > "$T/fakebin/git" <<'EOF'
#!/usr/bin/env bash
echo "GIT-WAS-CALLED: git $*" >&2
exit 99
EOF
chmod +x "$T/fakebin/git"

# ── stub nix: simulate `flake update` (bump rev) and `eval --raw` ──
cat > "$T/fakebin/nix" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "flake" && "${2:-}" == "update" ]]; then
  touch "$PWD/.fake-nix-update-called"
  sed -i 's/aaa111/aaa222/' flake.lock
  echo "warning: Git tree '/tmp' is dirty" >&2
  exit 0
fi
if [[ "${1:-}" == "eval" ]]; then
  echo "26.11pre-git"
  exit 0
fi
echo "UNEXPECTED nix call: $*" >&2
exit 98
EOF
chmod +x "$T/fakebin/nix"

# ── minimal flake (same node layout as the real flake.lock) ──
cat > "$T/flake.nix" <<'EOF'
{
  description = "fake";
  outputs = { ... }: { };
}
EOF
cat > "$T/flake.lock" <<'EOF'
{
  "nodes": {
    "nixpkgs-main": { "locked": { "rev": "aaa111" } },
    "root": {}
  },
  "root": "root",
  "version": 7
}
EOF
cp "$T/flake.nix" "$T/flake.lock" "$T/repo/"
cp "$T/flake.nix" "$T/flake.lock" "$T/nogit/"

# ── scenario 1: dirty git clone (setup with REAL git first) ──
git -C "$T/repo" init -q
git -C "$T/repo" add -A
git -C "$T/repo" -c user.email=t@t -c user.name=t commit -qm init
echo "# local hack" >> "$T/repo/flake.nix"   # dirty worktree, lock stays valid JSON

REAL_PATH="$PATH"
export PATH="$T/fakebin:$PATH"

# ── run 1: dirty clone ──
out=$(cd "$T/repo" && bash "$REPO/script/update-flake-local" 2>&1)
rc=$?
if (( rc == 0 )) && [[ -f "$T/repo/.fake-nix-update-called" ]] && ! grep -q GIT-WAS-CALLED <<<"$out"; then
  ok "dirty clone: exit 0, flake updated, git never called"
else
  ko "dirty clone (rc=$rc): $out"
fi
grep -q aaa222 "$T/repo/flake.lock" && ok "dirty clone: flake.lock rev bumped" || ko "dirty clone: rev not bumped"

# ── run 2: directory without .git ──
out=$(cd "$T/nogit" && bash "$REPO/script/update-flake-local" 2>&1)
rc=$?
if (( rc == 0 )) && [[ -f "$T/nogit/.fake-nix-update-called" ]] && ! grep -q GIT-WAS-CALLED <<<"$out"; then
  ok "no .git: exit 0, flake updated, git never called"
else
  ko "no .git (rc=$rc): $out"
fi

# ── run 3: wrong directory ──
mkdir -p "$T/empty"
if ! (cd "$T/empty" && bash "$REPO/script/update-flake-local" >/dev/null 2>&1); then
  ok "wrong dir: exits non-zero with root error"
else
  ko "wrong dir: should have failed"
fi

# ── run 4: INSTALL_NO_GIT=1 silences checkRepoVersion (even in dirty repo) ──
out=$(cd "$T/repo" && INSTALL_NO_GIT=1 bash -c 'source "'"$REPO"'/install-lib/lib.sh" >/dev/null 2>&1; checkRepoVersion; echo "rc=$?"' 2>&1)
if [[ "$out" == "rc=0" ]] && ! grep -q GIT-WAS-CALLED <<<"$out"; then
  ok "INSTALL_NO_GIT=1: checkRepoVersion returns 0 silently, git never called"
else
  ko "INSTALL_NO_GIT=1: got '$out'"
fi

# ── run 5: without INSTALL_NO_GIT, dirty repo still warns (default unchanged) ──
# NOTE: real git here (fake shadow removed), real dirty repo
out=$(cd "$T/repo" && PATH="$REAL_PATH" bash -c 'source "'"$REPO"'/install-lib/lib.sh" >/dev/null 2>&1; checkRepoVersion <<<"n"; echo "rc=$?"' 2>&1 || true)
if grep -q "uncommitted changes" <<<"$out"; then
  ok "default unchanged: dirty repo still warns without INSTALL_NO_GIT"
else
  ko "default behavior changed?! got '$out'"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
