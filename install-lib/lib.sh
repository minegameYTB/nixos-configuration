### This shell script is only here to use function and common variable

### Nix settings
nixFlags=(--extra-experimental-features "nix-command flakes")
nixpkgsRev="23d72dabcb3b12469f57b37170fcbc1789bd7457"

warn() {
  printf "\033[1;35mwarning:\033[0m %s\n" "$*" >&2
}

run_command() {
  echo -e "\n\033[1;34m▶ Run command:\033[0m"
  echo -e "  \033[33m$*\033[0m\n"
  "$@"
}
