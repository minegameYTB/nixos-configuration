#!/usr/bin/env bash
### PATH-coverage guards (the `cmp: command not found` class of bugs):
###  1. every external command used by each auto-update service script must
###     resolve to a package in THAT service's explicit environment.PATH
###     (hand-picked bin dirs, output-aware — update NEED when a script
###     gains commands, update PATH when NEED complains);
###  2. no `export PATH=` clobbering in home-manager activation blocks
###     (scope with `PATH="...:$PATH" cmd` instead).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="$REPO/configurations/modules/misc/auto-update.nix"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

KEYWORDS='then if fi else do done while for continue return local set shift exit echo true break'

# command -> explicit PATH entry (keep in sync with environment.PATH)
declare -A NEED=(
  [git]=pkgs.gitMinimal
  [nix]=config.nix.package
  [nixos-rebuild]=config.system.build.nixos-rebuild
  [jq]=pkgs.jq.bin
  [grep]=pkgs.gnugrep
  [sha256sum]=pkgs.coreutils
  [cut]=pkgs.coreutils
  [cat]=pkgs.coreutils
  [rm]=pkgs.coreutils
  [mkdir]=pkgs.coreutils
  [readlink]=pkgs.coreutils
  [cmp]=pkgs.diffutils
  [date]=pkgs.coreutils
  [head]=pkgs.coreutils
  [id]=pkgs.coreutils
  [loginctl]=config.systemd.package
  [systemctl]=config.systemd.package
  [runuser]=pkgs.util-linux.bin
  [notify-send]=pkgs.libnotify
)

# Per-service coverage: block, script and path are extracted from the same
# `systemd.services.<name>` definition, so a package missing from one
# service cannot hide behind the other service's path.
check_service(){
  local svc="$1"
  local BLOCK SCRIPT CANDS FUNCS PATHPKGS cmd covered=0
  BLOCK=$(awk "/systemd.services.$svc =.*\{/{f=1} f{print} f&&/^    \};\$/{exit}" "$MOD")
  [[ -n "$BLOCK" ]] || { ko "service block '$svc' not found in module"; return 0; }
  SCRIPT=$(printf '%s\n' "$BLOCK" | sed -n "/script = ''/,/'';/p" | tail -n +2 \
    | sed -E 's/\$\{[a-zA-Z0-9_.]+\}//g; s/#.*//')
  CANDS=$(printf '%s\n' "$SCRIPT" \
    | grep -oE '(^[ \t]*|[;&|][ \t]*|&&[ \t]*|\|\|[ \t]*|\$\([ \t]*)[a-z][a-z0-9_.-]*' \
    | sed -E 's/^[^a-z]*//' | sort -u)
  FUNCS=$(printf '%s\n' "$SCRIPT" | grep -oE '^[ \t]*[a-z_][a-z0-9_]*\(\)' \
    | sed -E 's/^[ \t]*([a-z_][a-z0-9_]*)\(\).*/\1/')
  LOCALS=$(printf '%s\n' "$SCRIPT" | grep -oE '^[ \t]*local [a-z0-9_ =]+' \
    | sed -E 's/^[ \t]*local //; s/=[^ ]*//g; s/ +/\n/g' | sort -u)
  PATHPKGS=$(printf '%s\n' "$BLOCK" | awk '/PATH = lib.mkForce/{f=1} f{print} f&&/\);/{exit}' \
    | grep -oE '\$\{[^}]+\}' | sed -E 's/^\$\{//; s/\}$//' | sort -u)
  while read -r cmd; do
    [[ -z "$cmd" ]] && continue
    if [[ " $KEYWORDS " == *" $cmd "* ]]; then continue; fi
    if grep -qFx "$cmd" <<<"$FUNCS"; then continue; fi
    if grep -qFx "$cmd" <<<"$LOCALS"; then continue; fi
    if grep -qF "\$$cmd" <<<"$SCRIPT"; then continue; fi
    if [[ -n "${NEED[$cmd]:-}" ]] && grep -qFx "${NEED[$cmd]}" <<<"$PATHPKGS"; then
      covered=$((covered+1)); continue
    fi
    ko "[$svc] command '$cmd' has no package in service path (extend path, or NEED if new)"
  done <<<"$CANDS"
  ok "[$svc] path covers $covered external commands"
}

check_service nixos-auto-update
check_service nixos-autoupdate-healthcheck

# ── 2. no PATH clobbering in home-manager activation ──
if grep -rn 'export PATH=' "$REPO/home-manager/" | grep -v '\$PATH' | grep -q .; then
  grep -rn 'export PATH=' "$REPO/home-manager/" | grep -v '\$PATH' >&2
  ko "export PATH= without :\$PATH suffix in home-manager (clobbers later activation steps)"
else
  ok "no PATH clobbering in home-manager activation"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
