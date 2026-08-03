### Common: constants, config loading, small helpers.
### Sourced by the nspawnctl entry point — never executed directly.

MACHINES_DIR="/var/lib/machines"
DATASET_ROOT="zroot/MACHINE"
DEFAULT_QUOTA="10G"
DEFAULT_COMPRESSION="zstd-3"
LX_SOURCES="smartos lxc ubuntu"
LX_REPOS="TritonDataCenter/lx-images omniosorg/lx-images"
LXC_STREAMS="https://images.linuxcontainers.org/streams/v1/images.json"
UBUNTU_CLOUD="https://cloud-images.ubuntu.com"
DEBOOTSTRAP_MIRROR="http://deb.debian.org/debian"
BRIDGE="systemd-nspawn"
DROPIN_DIR="${NSPAWNCTL_DROPIN_DIR:-/etc/systemd/nspawn}"

### /etc/nspawnctl.conf — overrides for the constants above and extra manual
### sources. Extra sources use URL templates with {os} and {version}, e.g.:
###   NSPAWNCTL_EXTRA_SOURCES=("mirror=https://mirror.example.com/images/{os}-{version}.tar.xz")
declare -A EXTRA_URLS=()
CONF=""

load_conf() {
  CONF="${NSPAWNCTL_CONF:-/etc/nspawnctl.conf}"
  EXTRA_URLS=()
  [[ -r "$CONF" ]] || return 0
  . "$CONF"
  for entry in "${NSPAWNCTL_EXTRA_SOURCES[@]:-}"; do
    name="${entry%%=*}"
    tmpl="${entry#*=}"
    if [[ -n "$name" && -n "$tmpl" && "$name" != "$tmpl" ]]; then
      EXTRA_URLS["$name"]="$tmpl"
      LX_SOURCES="$LX_SOURCES $name"
    fi
  done
}

### ANSI colour variables (same scheme as install-lib/lib.sh).
### Disabled when: NO_COLOR is set, TERM=dumb, or stdout is not a terminal.
if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-dumb}" == "dumb" ]] || ! [[ -t 1 ]]; then
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

### Logging helpers: info (cyan), ok (green), warn (magenta, stderr), die (red, stderr).
info() {
  printf '%b\n' "${CYAN}info:${RESET} $*"
}

ok() {
  printf '%b\n' "${GREEN}ok:${RESET} $*"
}

warn() {
  printf '%b\n' "${MAGENTA}warning:${RESET} $*" >&2
}

die() {
  printf '%b\n' "${RED}nspawnctl:${RESET} $*" >&2
  exit 1
}

valid_name() {
  [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "invalid machine name: $1"
}
