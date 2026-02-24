### This shell script is only here to use function and common variable

### Nix settings
nixFlags=(--extra-experimental-features "nix-command flakes")

### Get nixpkgs-main hash or use fallback hash
nixpkgsRev=$(jq -r '.nodes["nixpkgs-main"].locked.rev' flake.lock 2>/dev/null || echo "23d72dabcb3b12469f57b37170fcbc1789bd7457")

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
  printf "${BOLD}${MAGENTA}warning:${RESET} %s\n" "$*" >&2
}

info() {
  printf "${CYAN}info:${RESET} %s\n" "$*"
}

run_command() {
  printf "\n${BLUE}▶ Run command:${RESET}"
  printf "  ${YELLOW}%s${RESET}\n\n" "$*"
  "$@"
}
