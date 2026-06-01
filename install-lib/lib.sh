### This shell script is only here to use function and common variable

### Nix settings
nixFlags=(--extra-experimental-features "nix-command flakes")

### Get nixpkgs-main hash or use fallback hash
nixpkgsRev=$(jq -r '.nodes["nixpkgs-main"].locked.rev // empty' flake.lock 2>/dev/null) \
  || nixpkgsRev="23d72dabcb3b12469f57b37170fcbc1789bd7457"

if [[ -z "$nixpkgsRev" || "$nixpkgsRev" == "null" ]]; then
  nixpkgsRev="23d72dabcb3b12469f57b37170fcbc1789bd7457"
fi

### ANSI color variable
if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-dumb}" == "dumb" ]] || ! [[ -t 1 ]]; then
    # Set no color if terminal is runned in older Unix system
    BOLD="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" RESET=""
else
    BOLD='\033[1m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[1;34m'
    MAGENTA='\033[1;35m'
    CYAN='\033[1;36m'
    RESET='\033[0m'
fi

warn() {
  printf "${MAGENTA}warning:${RESET} %s\n" "$*" >&2
}

info() {
  printf "${CYAN}info:${RESET} %s\n" "$*"
}

run_command() {
  printf "\n${BLUE}▶ Run command:${RESET}"
  printf "  ${YELLOW}%s${RESET}\n\n" "$*"
  "$@"
}

# Read default username from flake.nix (users = [ "..." ]) and prompt for confirmation
# Usage: getDefaultUser <error_code>
# Exports: userName
getDefaultUser() {
  local errorCode="${1:-5}"

  local default_user
  default_user=$(grep -oP '(?<=users = \[ ")[^"]+' flake.nix 2>/dev/null | head -1 || true)

  read -r -p "What is your username? [${default_user}] " userName
  userName="${userName:-$default_user}"

  if [[ -z "$userName" ]]; then
    warn "No username provided and could not parse flake.nix (Error $errorCode)"
    exit "$errorCode"
  fi
}
