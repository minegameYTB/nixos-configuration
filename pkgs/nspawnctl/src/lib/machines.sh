### Subcommands: new, net, remove.
### Sourced by the nspawnctl entry point — never executed directly.

cmd_new() {
  local machine="$1"
  shift
  local spec="" tarball="" suite="" variant="minbase" arch="" quota="$DEFAULT_QUOTA" compression="$DEFAULT_COMPRESSION"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-tar) tarball="${2:-}"; shift 2 ;;
      --debootstrap) suite="${2:-}"; shift 2 ;;
      --variant) variant="${2:-}"; shift 2 ;;
      --arch) arch="${2:-}"; shift 2 ;;
      --quota) quota="${2:-}"; shift 2 ;;
      --compression) compression="${2:-}"; shift 2 ;;
      --*) usage ;;
      *) [[ -z "$spec" ]] && spec="$1" || usage; shift ;;
    esac
  done
  valid_name "$machine"

  local source="" image=""
  if [[ -n "$spec" ]]; then
    parse_spec "$spec"
    source="$G_SPEC_SOURCE"
    image="$G_SPEC_IMAGE"
  fi

  [[ -n "$tarball" || -n "$suite" || -n "$spec" ]] \
    || die "specify an image: <source>:<os>:<version> (see 'nspawnctl --list')"

  local ds="$DATASET_ROOT/$machine"
  local root="$MACHINES_DIR/$machine"

  zfs list "$ds" >/dev/null 2>&1 && die "dataset already exists: $ds"
  [[ -e "$root" ]] && die "already exists: $root"

  info "Creating dataset $ds (refquota=$quota, compression=$compression)"
  zfs create -p -o mountpoint="$root" -o refquota="$quota" -o compression="$compression" -o atime=off "$ds"
  [[ -d "$root" ]] || die "dataset did not mount at $root"

  if [[ -n "$tarball" ]]; then
    install_from_tar "$root" "$tarball"
  elif [[ -n "$suite" ]]; then
    info "debootstrap $suite (variant=$variant${arch:+, arch=$arch}) ..."
    debootstrap --variant="$variant" $([[ -n "$arch" ]] && echo --arch="$arch") "$suite" "$root" "$DEBOOTSTRAP_MIRROR"
  else
    install_lx "$root" "$image" "$source"
  fi
  net_enable "$machine"
}

cmd_net() {
  local machine="$1"
  shift
  local static=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --static) static="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  valid_name "$machine"
  [[ -d "$MACHINES_DIR/$machine" ]] || die "machine not found: $MACHINES_DIR/$machine"
  net_enable "$machine" "$static"
}

cmd_start() {
  local machine="$1"
  valid_name "$machine"
  local ds="$DATASET_ROOT/$machine"
  local root="$MACHINES_DIR/$machine"
  [[ -d "$root" ]] || die "machine not found: $root"
  zfs list "$ds" >/dev/null 2>&1 || die "no dataset $ds for machine '$machine'"
  if machinectl show "$machine" -p State 2>/dev/null | grep -q "State=running"; then
    info "machine '$machine' is already running"
    return 0
  fi
  machinectl start "$machine"
  info "machine '$machine' started"
}

### Open an interactive shell for a machine.
### Containers with systemd get `machinectl shell` (D-Bus session); other
### init systems get a direct namespace join via nsenter (machinectl enter
### was removed in systemd 258+).
cmd_shell() {
  local machine="$1"
  shift
  local user=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user) user="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  valid_name "$machine"
  local root="$MACHINES_DIR/$machine"
  [[ -d "$root" ]] || die "machine not found: $root"

  if [[ "$(detect_init "$root")" == "systemd" ]]; then
    if [[ -n "$user" ]]; then
      exec machinectl shell "$user@$machine"
    fi
    exec machinectl shell "$machine"
  fi
  if [[ -n "$user" ]]; then
    warn "--user is only supported with systemd inside the machine — ignoring"
  fi
  local leader=""
  leader=$(machinectl show "$machine" -p Leader 2>/dev/null | sed -n 's/^Leader=//p' || true)
  [[ -n "$leader" ]] || die "machine not running: $machine"
  local nsenter_bin shell_bin="/bin/sh"
  [[ -x "$root/bin/bash" ]] && shell_bin="/bin/bash"
  [[ -x "$root/usr/bin/bash" ]] && shell_bin="/usr/bin/bash"
  nsenter_bin=$(command -v nsenter)
  exec env -i PATH=/sbin:/bin:/usr/sbin:/usr/bin HOME=/root SHELL="$shell_bin" TERM="${TERM:-xterm}" \
    "$nsenter_bin" -t "$leader" -m -u -i -n -p -- "$shell_bin"
}

### Show machine type, runtime state and detected init/network. The init
### that is actually running comes from /proc/<Leader>/exe (truth); the
### static detect_init/detect_net reflect what 'new' configured.
cmd_info() {
  local machine="$1"
  valid_name "$machine"
  local root="$MACHINES_DIR/$machine"
  [[ -d "$root" ]] || die "machine not found: $root"

  local show="" state="not registered" leader="" ip=""
  show=$(machinectl show "$machine" -p State -p Leader -p IPAddress 2>/dev/null || true)
  state=$(sed -n 's/^State=//p' <<<"$show")
  leader=$(sed -n 's/^Leader=//p' <<<"$show")
  ip=$(sed -n 's/^IPAddress=//p' <<<"$show")
  [[ -n "$state" ]] || state="not registered"

  echo "machine:        $machine"
  echo "type:           container"
  echo "state:          $state"

  local init="(n/a)"
  if [[ -n "$leader" ]]; then
    local exe=""
    exe=$(readlink "/proc/$leader/exe" 2>/dev/null || true)
    case "$exe" in
      *systemd) init="systemd" ;;
      *busybox)
        if [[ -e "$root/etc/nspawnctl-init" ]]; then
          init="busybox (injected rescue init)"
        else
          init="busybox (native)"
        fi
        ;;
      *tini) init="tini (bare SmartOS zone init)" ;;
      *"/init" | *"/sbin/init") init="$(basename "$exe") (sysvinit/openrc)" ;;
      "") init="(unreadable)" ;;
      *) init="$(basename "$exe")" ;;
    esac
  fi
  echo "init (running): $init"

  case "$(detect_init "$root")" in
    systemd) echo "detect_init:    systemd" ;;
    other) echo "detect_init:    other (has sbin/init)" ;;
    none) echo "detect_init:    none (busybox injected)" ;;
  esac

  case "$(detect_net "$root")" in
    networkd) echo "network:        systemd-networkd" ;;
    ifupdown) echo "network:        ifupdown" ;;
    none)
      if [[ -e "$root/usr/local/sbin/nspawnctl-net.sh" ]]; then
        echo "network:        busybox net script"
      else
        echo "network:        none (re-run: nspawnctl net $machine)"
      fi
      ;;
  esac
  if [[ -z "$ip" && "$state" == "running" ]]; then
    ip=$(machine_ip "$machine" 2>/dev/null || true)
  fi
  if [[ -n "$ip" ]]; then
    echo "ip:             $ip"
  elif [[ "$state" == "running" ]]; then
    echo "ip:             (no IP yet)"
  else
    echo "ip:             (stopped)"
  fi
}

cmd_remove() {
  local machine ds root ans
  for machine in "$@"; do
    valid_name "$machine"
    ds="$DATASET_ROOT/$machine"
    root="$MACHINES_DIR/$machine"
    zfs list "$ds" >/dev/null 2>&1 || die "no dataset $ds for machine '$machine'"

    echo "This will destroy: $ds (dataset, children and snapshots)"
    read -r -p "Proceed? [y/N] " ans || ans=""
    [[ "$ans" == "y" || "$ans" == "Y" ]] || { info "skipped '$machine'"; continue; }

    if machinectl status "$machine" >/dev/null 2>&1; then
      machinectl stop "$machine"
      local down=0
      local stop_timeout="${NSPAWNCTL_STOP_TIMEOUT:-30}"
      for _ in $(seq 1 "$stop_timeout"); do
        if ! machinectl status "$machine" >/dev/null 2>&1; then
          down=1
          break
        fi
        sleep 1
      done
      if [[ $down -ne 1 ]]; then
        warn "$machine ignored SIGRTMIN+4 (non-systemd init) — terminating it"
        machinectl terminate "$machine" \
          || die "machinectl terminate $machine failed — run it manually: machinectl terminate $machine"
      fi
    fi
    ### Make sure nothing is mounted under the machine before destroying:
    ### systemd-nspawn releases the mount asynchronously and a lingering
    ### process (e.g. an nsenter 'shell' session) keeps the dataset busy.
    for _ in $(seq 1 "${NSPAWNCTL_UNMOUNT_TIMEOUT:-10}"); do
      [[ "$(zfs get -H -o value mounted "$ds" 2>/dev/null)" != "yes" ]] && break
      sleep 1
    done
    zfs unmount "$ds" 2>/dev/null || true
    rm -f "$DROPIN_DIR/$machine.nspawn"
    remove_net_files "$root"

    zfs destroy -r "$ds" || die "zfs destroy $ds failed (dataset busy) — is '$machine' still running? machinectl status $machine; force with: sudo zfs destroy -rf $ds"
    rmdir "$root" 2>/dev/null || true
    ok "machine '$machine' removed"
  done
}
