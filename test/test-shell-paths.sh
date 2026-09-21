#!/usr/bin/env bash
### PATH-coverage guards (the `cmp: command not found` class of bugs):
###  1. every external command used by each auto-update service script must
###     resolve to a package in THAT service's explicit environment.PATH.
###     Scripts are assembled from fragments (see assemble() below — keep in
###     sync with configurations/modules/misc/auto-update/default.nix);
###     when a fragment gains commands, extend NEED and/or the service PATH.
###  2. no `export PATH=` clobbering in home-manager activation blocks.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-fragments.sh
source "$REPO/test/lib-fragments.sh"
AUDIR="$REPO/configurations/modules/misc/auto-update"
SVCNIX="$AUDIR/services.nix"
T=/tmp/opencode/shell-paths-test
rm -rf "$T"; mkdir -p "$T"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

KEYWORDS='then if fi else elif do done while for continue return local set shift exit echo true break case esac in printf exec trap'

# command -> explicit PATH entry (keep in sync with environment.PATH).
# When services use the tight envs (env.nix), the actual PATH is a
# single ${env.<tier>}/bin — the test expands that env to its
# underlying pkgs/config constituents via ENV_CONTENTS below.
declare -A NEED=(
  [git]=pkgs.gitMinimal
  [nix]=config.nix.package
  [nix-env]=config.nix.package
  [nixos-rebuild]=config.system.build.nixos-rebuild
  [curl]=pkgs.curl
  [awk]=pkgs.gawk
  [sed]=pkgs.gnused
  [nvd]=pkgs.nvd
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
  [basename]=pkgs.coreutils
  [env]=pkgs.coreutils
  [timeout]=pkgs.coreutils
  [sync]=pkgs.coreutils
  [mktemp]=pkgs.coreutils
  [chmod]=pkgs.coreutils
  [mv]=pkgs.coreutils
  [base64]=pkgs.coreutils
  [sleep]=pkgs.coreutils
  [df]=pkgs.coreutils
  [stat]=pkgs.coreutils
  [flock]=pkgs.util-linux.bin
  [wall]=pkgs.util-linux.bin
  [touch]=pkgs.coreutils
  [systemctl]=config.systemd.package
  [runuser]=pkgs.util-linux.bin
  [notify-send]=pkgs.libnotify
)
declare -A ENV_CONTENTS=(
  [env.core]="pkgs.coreutils
pkgs.libnotify"
  [env.health]="pkgs.coreutils
pkgs.util-linux.bin
pkgs.libnotify
config.systemd.package
pkgs.gnugrep"
  [env.main]="pkgs.coreutils
pkgs.util-linux.bin
pkgs.libnotify
config.systemd.package
pkgs.gnugrep
config.nix.package
config.system.build.nixos-rebuild
pkgs.gitMinimal
pkgs.diffutils
pkgs.curl
pkgs.gawk
pkgs.gnused
pkgs.nvd"
)

# assemble <out> <fragment-spec>... — fragment-spec is "file:marker".
# Nix ${...} interpolations are stripped (values do not matter for PATH
# scanning; multi-line lib.optionalString wrappers stay inert).
assemble(){
  local out="$1"; shift
  : > "$out"
  local spec f m
  for spec in "$@"; do
    f="${spec%%:*}"; m="${spec#*:}"
    fragment "$f" "$m" >> "$out"
  done
  sed -E -i 's/\$\{[a-zA-Z0-9_.]+\}//g' "$out"
}

# Expected PATH contents per service are read live from default.nix pathX
# blocks (drift guard below); NEED above maps commands to those entries.
# Path blocks compose via `++` (pathMain = pathHealth ++ [...]); resolve the
# full entry set recursively so inherited packages count.
declare -A _PATH_SEEN=()
_path_block_recurse(){
  local block="$1" dep raw
  [[ -n "${_PATH_SEEN[$block]:-}" ]] && return 0
  _PATH_SEEN[$block]=1
  local text
  text=$(awk "/^  $block =/{f=1} f{print} f&&/\];/{exit}" "$SVCNIX")
  while IFS= read -r raw; do
    raw=$(sed -E 's/^\$\{//; s/\}$//' <<<"$raw")
    if [[ "$raw" == env.* ]]; then
      # expand tight env to its underlying pkgs/config set
      if [[ -n "${ENV_CONTENTS[$raw]:-}" ]]; then
        printf '%s\n' "${ENV_CONTENTS[$raw]}"
      else
        echo "$raw"
      fi
    else
      echo "$raw"
    fi
  done < <(grep -oE '\$\{(pkgs\.[a-zA-Z0-9_.-]+|config\.[a-zA-Z0-9_.-]+|env\.[a-z]+)\}' <<<"$text")
  for dep in $(grep -oE '\bpath[A-Z][A-Za-z]*\b' <<<"$text" | sort -u); do
    [[ "$dep" == "$block" ]] && continue
    _path_block_recurse "$dep"
  done
}
path_block_pkgs(){
  _PATH_SEEN=()
  _path_block_recurse "$1" | tr ' ' '\n' | grep -v '^$' | sort -u
}

# scan_prep <in> <out> — strip scanner noise, keep code:
# full-line comments, case labels (no parens, ending in `)` — `foo() {`
# definitions are kept — and `|`, `;`, `&&` inside double-quoted strings
# (state `"a|b|c"`, `"...; ..."` message texts). $(...) stays intact.
scan_prep(){
  sed -e ':j' -e '/\\$/N; s/\\\n//; tj' "$1" \
    | grep -v '^[ \t]*#' \
    | grep -v '^[ \t]*[^ ()]*).*' \
    | sed -e ':a' -e 's/\("[^"]*\)[|;]\([^"]*"\)/\1 \2/;ta' \
          -e ':b' -e 's/\("[^"]*\)&&\([^"]*"\)/\1 \2/;tb' > "$2"
}

check_service(){
  local svc="$1" script="$2" pathname="$3"
  local CANDS FUNCS LOCALS PATHPKGS cmd covered=0
  scan_prep "$script" "$T/prep-code.sh"
  CANDS=$(grep -oE '(^[ \t]*|[;&|][ \t]*|&&[ \t]*|\|\|[ \t]*|\$\([ \t]*)[a-z][a-z0-9_.-]*' "$T/prep-code.sh" \
    | sed -E 's/^[^a-z]*//' | sort -u)
  FUNCS=$(grep -oE '^[ \t]*[a-z_][a-z0-9_]*\(\)' "$T/prep-code.sh" \
    | sed -E 's/^[ \t]*([a-z_][a-z0-9_]*)\(\).*/\1/')
  LOCALS=$(grep -oE '^[ \t]*local [a-z0-9_ =]+' "$T/prep-code.sh" \
    | sed -E 's/^[ \t]*local //; s/=[^ ]*//g; s/ +/\n/g' | sort -u)
  PATHPKGS=$(path_block_pkgs "$pathname")
  while read -r cmd; do
    [[ -z "$cmd" ]] && continue
    if [[ " $KEYWORDS " == *" $cmd "* ]]; then continue; fi
    if grep -qFx "$cmd" <<<"$FUNCS"; then continue; fi
    if grep -qFx "$cmd" <<<"$LOCALS"; then continue; fi
    if grep -qF "\$$cmd" <<<"$(cat "$T/prep-code.sh")"; then continue; fi
    if [[ -n "${NEED[$cmd]:-}" ]] && grep -qFx "${NEED[$cmd]}" <<<"$PATHPKGS"; then
      covered=$((covered+1)); continue
    fi
    ko "[$svc] command '$cmd' has no package in service path (extend path, or NEED if new)"
  done <<<"$CANDS"
  ok "[$svc] path covers $covered external commands"
}

# ── assemble the four service scripts ──
assemble "$T/main.sh" \
  errors.nix:errors output.nix:output-core output.nix:output-render \
  notifier.nix:notifier-user notifier.nix:notifier-root \
  transaction.nix:transaction sync.nix:sync services.nix:main-flow
assemble "$T/failure.sh" \
  errors.nix:errors output.nix:output-core \
  notifier.nix:notifier-user notifier.nix:notifier-root \
  services.nix:failure-flow
assemble "$T/health.sh" \
  errors.nix:errors output.nix:output-core \
  notifier.nix:notifier-user notifier.nix:notifier-root \
  transaction.nix:transaction health.nix:health services.nix:health-flow
assemble "$T/pending.sh" \
  notifier.nix:notifier-user

for spec in "nixos-auto-update:$T/main.sh:pathMain" \
            "nixos-auto-update-notify-failure:$T/failure.sh:pathHealth" \
            "nixos-autoupdate-healthcheck:$T/health.sh:pathHealth"; do
  svc="${spec%%:*}"; rest="${spec#*:}"; script="${rest%%:*}"; pname="${rest##*:}"
  check_service "$svc" "$script" "$pname"
done

# user pending service: via env.core (coreutils + libnotify)
path_block_pkgs "pathCore" > "$T/pending-path"
CANDS=$(scan_prep "$T/pending.sh" "$T/prep-pending.sh" \
  && grep -oE '(^[ \t]*|[;&|][ \t]*|&&[ \t]*|\|\|[ \t]*|\$\([ \t]*)[a-z][a-z0-9_.-]*' "$T/prep-pending.sh" \
  | sed -E 's/^[^a-z]*//' | sort -u)
FUNCS=$(grep -oE '^[ \t]*[a-z_][a-z0-9_]*\(\)' "$T/prep-pending.sh" \
  | sed -E 's/^[ \t]*([a-z_][a-z0-9_]*)\(\).*/\1/')
LOCALS=$(grep -oE '^[ \t]*local [a-z0-9_ =]+' "$T/prep-pending.sh" \
  | sed -E 's/^[ \t]*local //; s/=[^ ]*//g; s/ +/\n/g' | sort -u)
covered=0
while read -r cmd; do
  [[ -z "$cmd" ]] && continue
  if [[ " $KEYWORDS " == *" $cmd "* ]]; then continue; fi
  if grep -qFx "$cmd" <<<"$FUNCS"; then continue; fi
  if grep -qFx "$cmd" <<<"$LOCALS"; then continue; fi
  if grep -qF "\$$cmd" <<<"$(cat "$T/prep-pending.sh")"; then continue; fi
  if [[ -n "${NEED[$cmd]:-}" ]] && grep -qFx "${NEED[$cmd]}" <<<"$(cat "$T/pending-path")"; then
    covered=$((covered+1)); continue
  fi
  ko "[pending] command '$cmd' has no package in service path"
done <<<"$CANDS"
ok "[pending] path covers $covered external commands"

# ── bash -n syntax gate on assembled flows (catches broken `\`
# continuations and bad nesting — the PATH scan cannot see those) ──
check_syntax(){
  local svc="$1" script="$2"
  local resolved="$T/syntax-$svc.sh"
  # Resolve Nix interpolations to inert values, drop lib.optionalString
  # wrapper lines (keep their inner bash), de-escape ''${...} to ${...}.
  sed -e 's|\${lib\.optionalString.*'"''"'$|REMOVED_NIX_WRAPPER|' \
      -e "s|^ *''}$|REMOVED_NIX_WRAPPER|" \
      -e 's|\${lib[^}]*}|_lib_|g' \
      -e 's|\${[a-zA-Z0-9_.]*}|_|g' \
      -e "s|''\\\${|\\\${|g" \
      -e '/^ *REMOVED_NIX_WRAPPER$/d' \
      -e '/^ *_lib_$/d' "$script" > "$resolved"
  if bash -n "$resolved"; then
    ok "[$svc] bash -n clean"
  else
    ko "[$svc] bash syntax error"
  fi
}

for spec in "nixos-auto-update:$T/main.sh" \
            "nixos-auto-update-notify-failure:$T/failure.sh" \
            "nixos-autoupdate-healthcheck:$T/health.sh" \
            "pending:$T/pending.sh"; do
  svc="${spec%%:*}"; script="${spec#*:}"
  check_syntax "$svc" "$script"
done

# ── continuation gate: a lone `"..."` line is only valid as a `\`-continued
# argument. A missing backslash turns it into a bogus command (`"normal":
# command not found` seen in prod). bash -n cannot see this — scan payloads.
{
  for spec in errors.nix:errors output.nix:output-core output.nix:output-render \
              notifier.nix:notifier-user notifier.nix:notifier-root \
              transaction.nix:transaction sync.nix:sync health.nix:health \
              services.nix:main-flow services.nix:failure-flow services.nix:health-flow; do
    f="${spec%%:*}"; m="${spec#*:}"
    echo "FILE:$f:$m"
    fragment "$f" "$m"
  done
} > "$T/allfrag.txt"
if awk '/^FILE:/ { cur = $0; prev_bs = 0; next }
  {
    if ($0 ~ /^[ \t]*"[^"]*"[ \t]*$/ && ! prev_bs) {
      print "VIOLATION " cur " :: " $0
      bad = 1
    }
    prev_bs = ($0 ~ /\\$/)
  }
  END { exit bad }' "$T/allfrag.txt"; then
  ok "no orphaned quoted-string commands (continuations intact)"
else
  ko "orphaned quoted-string line would run as a command"
fi

# ── drift guard: EXPECTED path blocks exist in services.nix ──
for pname in pathMain pathHealth pathCore; do
  if grep -q "^  $pname =" "$SVCNIX"; then
    ok "path block $pname present in services.nix"
  else
    ko "path block $pname missing in services.nix"
  fi
done

# ── no mount-sandboxing on root services ──
BANNED='ProtectSystem|ProtectHome|PrivateTmp|PrivateDevices|ProtectKernelTunables|ProtectKernelModules|ProtectControlGroups|RestrictNamespaces|NoNewPrivileges|ReadWritePaths|ReadOnlyPaths'
for svc in nixos-auto-update nixos-auto-update-notify-failure nixos-autoupdate-healthcheck; do
  if awk "/systemd.services.$svc =.*\{/{f=1} f{print} f&&/^    \};\$/{exit}" "$SVCNIX" \
    | grep -Eq "^\s*($BANNED)\s*="; then
    ko "[$svc] mount-sandboxing key present (breaks nix builds, see module comments)"
  else
    ok "[$svc] no mount-sandboxing keys"
  fi
done

# ── no PATH clobbering in home-manager activation ──
if grep -rn 'export PATH=' "$REPO/home-manager/" | grep -v '\$PATH' | grep -q .; then
  grep -rn 'export PATH=' "$REPO/home-manager/" | grep -v '\$PATH' >&2
  ko "export PATH= without :\$PATH suffix in home-manager (clobbers later activation steps)"
else
  ok "no PATH clobbering in home-manager activation"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
