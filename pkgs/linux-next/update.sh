#!/usr/bin/env bash
set -euo pipefail

### Refresh the linux-next pin used by default.nix in this directory.
### Resolves a rev (default: current HEAD of linux-next.git), shallow-prefetches
### it, derives the real kernelrelease (Makefile + localversion* files) and
### prints the values. With --write, patches default.nix in place.
###
### Usage: ./update.sh [--rev <sha1>] [--write]

URL="https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
REV=""
WRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rev)
      REV="${2:?missing value for --rev}"
      shift 2
      ;;
    --write)
      WRITE=1
      shift
      ;;
    -h | --help)
      sed -n '2,/^$/p' "$0"
      echo "Usage: $0 [--rev <sha1>] [--write]"
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

for cmd in git jq nix; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' not found in PATH" >&2
    exit 1
  fi
done

if [[ -z "$REV" ]]; then
  echo "Resolving HEAD of linux-next.git..." >&2
  REV="$(git ls-remote "$URL" HEAD | awk '{print $1}')"
fi
echo "rev: $REV" >&2

echo "Prefetching (shallow)..." >&2
INFO="$(nix run nixpkgs#nix-prefetch-git -- --url "$URL" --rev "$REV" --no-deepClone --quiet)"
HASH="$(jq -r '.hash' <<<"$INFO")"
SRC_PATH="$(jq -r '.path' <<<"$INFO")"
COMMIT_DATE="$(jq -r '.date' <<<"$INFO")"

# kernelrelease = VERSION.PATCHLEVEL.SUBLEVEL + EXTRAVERSION + localversion*
major="$(awk '/^VERSION =/ {print $3}' "$SRC_PATH/Makefile")"
minor="$(awk '/^PATCHLEVEL =/ {print $3}' "$SRC_PATH/Makefile")"
sublevel="$(awk '/^SUBLEVEL =/ {print $3}' "$SRC_PATH/Makefile")"
extra="$(awk '/^EXTRAVERSION =/ {print $3}' "$SRC_PATH/Makefile")"
localversions="$(cat "$SRC_PATH"/localversion* 2>/dev/null | tr -d '\n' || true)"
KRELEASE="${major}.${minor}.${sublevel}${extra}${localversions}"

cat <<EOF
--- linux-next pin (commit date: $COMMIT_DATE) ---
version = "$KRELEASE"
rev = "$REV"
hash = "$HASH"
EOF

if [[ "$WRITE" -eq 1 ]]; then
  NIX_FILE="$(dirname "$0")/default.nix"
  for pattern in "version = " "rev = " "hash = "; do
    count="$(grep -c -E "^[[:space:]]*${pattern}\"" "$NIX_FILE")"
    if [[ "$count" -ne 1 ]]; then
      echo "error: expected exactly 1 '${pattern}' line in $NIX_FILE, found $count (aborting)" >&2
      exit 1
    fi
  done
  sed -i -E \
    -e "s|^([[:space:]]*version = \").*(\";)$|\1$KRELEASE\2|" \
    -e "s|^([[:space:]]*rev = \").*(\";)$|\1$REV\2|" \
    -e "s|^([[:space:]]*hash = \").*(\";)$|\1$HASH\2|" \
    "$NIX_FILE"
  echo "Updated $NIX_FILE" >&2
fi
