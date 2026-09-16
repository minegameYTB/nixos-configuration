#!/usr/bin/env bash
### Unit tests for lib/repo-info.nix (pure builtins, offline):
### GitHub / GitLab (incl. nested groups) / Codeberg / self-hosted /
### SSH remotes resolve to the right forge, slug, git URL and flake ref.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pass=0; fail=0
ok(){ pass=$((pass+1)); echo "PASS: $*"; }
ko(){ fail=$((fail+1)); echo "FAIL: $*" >&2; }

check(){
  local name="$1" url="$2" expected="$3"
  local got
  got=$(nix-instantiate --eval --strict --json --expr "
    let r = import $REPO/lib/repo-info.nix { url = \"$url\"; channel = \"chan\"; };
    in [ r.host r.slug r.gitUrl r.flakeRef ]" | jq -r 'join("|")')
  if [[ "$got" == "$expected" ]]; then
    ok "$name"
  else
    ko "$name (got: $got)"
  fi
}

check "github" \
  "https://github.com/minegameYTB/nixos-configuration" \
  "github|minegameYTB/nixos-configuration|https://github.com/minegameYTB/nixos-configuration.git|github:minegameYTB/nixos-configuration?ref=chan"

check "github with .git suffix and trailing slash" \
  "https://github.com/minegameYTB/nixos-configuration.git/" \
  "github|minegameYTB/nixos-configuration|https://github.com/minegameYTB/nixos-configuration.git|github:minegameYTB/nixos-configuration?ref=chan"

check "gitlab nested groups" \
  "https://gitlab.com/group/sub/repo" \
  "gitlab|group/sub/repo|https://gitlab.com/group/sub/repo.git|gitlab:group/sub/repo?ref=chan"

check "codeberg generic https" \
  "https://codeberg.org/owner/repo" \
  "https|owner/repo|https://codeberg.org/owner/repo.git|git+https://codeberg.org/owner/repo.git?ref=chan"

check "self-hosted https" \
  "https://git.example.com/a/b" \
  "https|a/b|https://git.example.com/a/b.git|git+https://git.example.com/a/b.git?ref=chan"

check "ssh remote" \
  "git@github.com:owner/repo.git" \
  "ssh|owner/repo|git@github.com:owner/repo.git|git+ssh://git@github.com/owner/repo.git?ref=chan"

if nix-instantiate --eval --strict --json --expr \
  "(import $REPO/lib/repo-info.nix { url = \"not-a-url\"; channel = \"c\"; }).host" >/dev/null 2>&1; then
  ko "garbage URL accepted"
else
  ok "garbage URL rejected"
fi

echo "--- $pass passed, $fail failed ---"
(( fail == 0 ))
