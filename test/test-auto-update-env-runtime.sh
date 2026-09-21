#!/usr/bin/env bash
### Runtime-dependency guard for the tight service envs (env.nix).
###
### Background (2026-09-20 incident): `nixos-rebuild boot` failed with
### `[Errno 2] No such file or directory: 'test'`, rolling back the whole
### transaction (rebuild-boot). Root cause: nixos-rebuild-ng is Python and
### spawns helpers via subprocess with NO shell — bash builtins like `[`
### do NOT help. Our services mkForce a single ${env.<tier>}/bin as PATH,
### so WE own every runtime dep of nixos-rebuild-ng too, not just our bash.
###
### test-shell-paths.sh only scans OUR bash fragments — it cannot see what
### nixos-rebuild-ng's Python calls. This suite pins the curated list below
### (audited from nixos-rebuild-ng 26.11 site-packages/nixos_rebuild/*.py)
### against env.nix mainBins, so pruning an entry fails loudly here instead
### of on a VM at boot-install time.
###
### Provenance (nixos-rebuild-ng 26.11, local boot path: build --flake + boot):
###   test        — nix.py:670 set_profile (`test -f <cfg>/nixos-version`),
###                 nix.py:733 switch_to_configuration (`test -d /run/...`).
###                 THE incident: missing test aborted boot after a good build.
###   systemd-run — nix.py:38 SWITCH_TO_CONFIGURATION_CMD_PREFIX (+elevate.py:281);
###                 prefixes switch-to-configuration when systemd is up.
###                 Without it, boot fails with Errno 2 right after test passes.
###   mkdir       — nix.py set_profile (custom-profile mkdir -p; harmless locally).
###   nix-env     — nix.py set_profile (`nix-env -p <profile> --set <cfg>`).
###   rm          — nix.py:149 remote-tmpdir cleanup (require anyway: ours uses rm).
###   nix         — nix.py build_flake (`nix build --print-out-paths`).
###   git         — nix.py:404,417 flake metadata (rev-parse/diff --quiet).
###   mktemp      — nix.py:126 remote-tmpdir helper (ours uses mktemp too).
###   readlink    — nix.py:145 remote-tmpdir helper (ours uses readlink too).
###   env         — process.py _prefix_env_cmd (`env -i K=V ... cmd`).
###   systemctl   — our own health/rollback flows.
###   nix-store / nix-build / nix-instantiate
###               — classic/remote/channel paths; all shipped by the nix package
###                 already in the closure, required here as edge-case insurance
###                 against nixpkgs refactors moving calls across paths.
### Excluded on purpose (unreachable from our service):
###   ssh / nix-copy-closure — remote builds only; service is local-only.
###   nano ($EDITOR) / repl  — `edit`/`repl` actions; service calls build/boot only.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIR="$REPO/configurations/modules/misc/auto-update"
ENVNIX="$AUDIR/env.nix"
T=/tmp/opencode/env-runtime-test
rm -rf "$T"; mkdir -p "$T"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

# Curated runtime deps for the main env (nixos-rebuild boot path).
# Keep in sync with env.nix mainBins + the provenance above.
RUNTIME_DEPS=(
  test
  systemd-run
  mkdir
  nix-env
  rm
  nix
  git
  mktemp
  readlink
  env
  systemctl
  nix-store
  nix-build
  nix-instantiate
)

# Extract the mainBins block (from "  mainBins = " to its closing "];").
# NOTE: the line reads `mainBins = coreBins ++ [`, not `mainBins = [` —
# match the assignment, not the bracket. mainBins inherits coreBins, so
# extract that block too and check membership in either.
awk '/^  mainBins =/{f=1} f{print} f&&/\];/{exit}' "$ENVNIX" > "$T/mainbins.txt"
awk '/^  coreBins =/{f=1} f{print} f&&/\];/{exit}' "$ENVNIX" > "$T/corebins.txt"
in_main_bins() {
  grep -q "/bin/$1\"" "$T/mainbins.txt" || grep -q "/bin/$1\"" "$T/corebins.txt"
}

# 1. every curated dep must be symlinked in mainBins (or inherited coreBins)
#    as /bin/<cmd>"
for cmd in "${RUNTIME_DEPS[@]}"; do
  if in_main_bins "$cmd"; then
    ok "[main] runtime dep present in env.nix: $cmd"
  else
    ko "[main] runtime dep MISSING from env.nix mainBins: $cmd (nixos-rebuild boot needs it — see header provenance)"
  fi
done

# 2. explicit regression for the 2026-09-20 incident (test binary).
if grep -q 'coreutils}/bin/test"' "$ENVNIX"; then
  ok "[core] test binary pinned (2026-09-20 rebuild-boot incident)"
else
  ko "[core] test binary missing — nixos-rebuild boot WILL fail with Errno 2"
fi

# 3. systemd-run must come from the systemd package (same one as systemctl).
if grep -q 'systemd.package}/bin/systemd-run"' "$ENVNIX"; then
  ok "[main] systemd-run sourced from config.systemd.package"
else
  ko "[main] systemd-run not sourced from config.systemd.package"
fi

# 4. live checks (only when nix is available, e.g. CI/dev machine):
#    build each env, assert no dangling symlinks and every curated dep resolves.
#    NOTE: use the `.` flake ref (not "$REPO#...") — the absolute-path form
#    spuriously reports "does not provide attribute" in some environments
#    while `.` resolves fine; CI uses `.` too.
if command -v nix >/dev/null 2>&1; then
  cd "$REPO" || { ko "[live] cannot cd to $REPO"; }
  for e in core health main; do
    out=$(nix build ".#nixos-auto-update-env-$e" --print-out-paths 2>/dev/null | tail -1) || {
      ko "[live] nix build '.#nixos-auto-update-env-$e' failed (hint: git add new files first — untracked paths are invisible to nix)"
      continue
    }
    if [ ! -d "$out/bin" ]; then
      ko "[live] $out/bin missing for env $e"
      continue
    fi
    ok "[live] built nixos-auto-update-env-$e"
    # dangling symlinks = typo'd source path (ln -s succeeds anyway)
    if dangling=$(find "$out/bin" -xtype l); [ -n "$dangling" ]; then
      ko "[live] dangling symlinks in env $e: $dangling"
    else
      ok "[live] no dangling symlinks in env $e"
    fi
  done
  main_out=$(nix build ".#nixos-auto-update-env-main" --print-out-paths 2>/dev/null | tail -1) || main_out=""
  if [ -n "$main_out" ] && [ -d "$main_out/bin" ]; then
    for cmd in "${RUNTIME_DEPS[@]}"; do
      if PATH="$main_out/bin" command -v "$cmd" >/dev/null 2>&1; then
        ok "[live] resolves in main env PATH: $cmd"
      else
        ko "[live] does NOT resolve in main env PATH: $cmd"
      fi
    done
  fi
else
  echo "SKIP: live checks (no nix in PATH)"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
