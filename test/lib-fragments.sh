#!/usr/bin/env bash
### Shared helper for auto-update fragment tests: extract verbatim bash
### between `# >>>BEGIN <marker>` / `# <<<END <marker>` from
### configurations/modules/misc/auto-update/*.nix (no indentation coupling,
### no duplication across test files).
# shellcheck disable=SC2034
AU_FRAGMENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configurations/modules/misc/auto-update" && pwd)"

# fragment <file> <marker> [out] — print (or write) the payload lines.
# Markers may be indented (Nix literals); leading whitespace is ignored.
# NOTE: the awk program must never redirect to /dev/stdout itself — reopening
# a regular file that way truncates it (gawk fopen "w"), which silently eats
# previously appended fragments. Redirection happens at the shell level only.
fragment() {
  local file="$1" marker="$2" out="${3:-/dev/stdout}"
  if [[ "$out" == /dev/stdout ]]; then
    awk -v m="$marker" '
      { line = $0; sub(/^[ \t]+/, "", line) }
      index(line, "# >>>BEGIN " m) == 1 { f = 1; next }
      index(line, "# <<<END " m) == 1 { f = 0; next }
      f { print }
    ' "$AU_FRAGMENT_DIR/$file"
  else
    awk -v m="$marker" '
      { line = $0; sub(/^[ \t]+/, "", line) }
      index(line, "# >>>BEGIN " m) == 1 { f = 1; next }
      index(line, "# <<<END " m) == 1 { f = 0; next }
      f { print }
    ' "$AU_FRAGMENT_DIR/$file" > "$out"
  fi
}
