### Installers: rootfs tarballs and debootstrap.
### Sourced by the nspawnctl entry point — never executed directly.

install_lx() {
  local root="$1" image="$2" source="$3" url tmp
  url=$(lx_url "$source" "$image")
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  info "Downloading '$image' (source: $source): $url"
  curl -fSL "$url" -o "$tmp"
  info "Extracting rootfs..."
  tar -xJf "$tmp" -C "$root"
  rm -f "$tmp"
  trap - EXIT
}

install_from_tar() {
  local root="$1" src="$2" tmp=""
  if [[ "$src" == http://* || "$src" == https://* ]]; then
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    info "Downloading $src"
    curl -fSL "$src" -o "$tmp" || die "download failed: $src"
    src="$tmp"
  else
    [[ -r "$src" ]] || die "cannot read tarball: $src"
  fi
  info "Extracting rootfs..."
  tar -xJf "$src" -C "$root"
  [[ -n "$tmp" ]] && rm -f "$tmp"
  trap - EXIT
}

### Detect the init system present in a rootfs.
### Prints: systemd | other | none
detect_init() {
  local root="$1"
  if [[ -e "$root/usr/lib/systemd/systemd" || -e "$root/lib/systemd/systemd" ]]; then
    echo systemd
  elif [[ -e "$root/sbin/init" || -e "$root/init" ]]; then
    echo other
  else
    echo none
  fi
}

### Detect which network configuration mechanism the rootfs supports.
### Prints: networkd | ifupdown | none
detect_net() {
  local root="$1"
  if [[ -e "$root/usr/lib/systemd/system/systemd-networkd.service" || -e "$root/lib/systemd/system/systemd-networkd.service" ]]; then
    echo networkd
  elif [[ -e "$root/etc/network/interfaces" && -e "$root/sbin/ifup" ]]; then
    echo ifupdown
  else
    echo none
  fi
}

### Ensure the rootfs has a bootable init.
### Rootfs without any init (bare SmartOS zone images) are rescued by
### injecting a static busybox binary: /sbin/init + /etc/inittab with a
### shell on the console. Dies if injection is impossible.
ensure_init() {
  local root="$1"
  case "$(detect_init "$root")" in
    systemd | other) return 0 ;;
  esac
  info "rootfs has no init — injecting static busybox init"
  [[ -n "$BUSYBOX" && -x "$BUSYBOX" ]] \
    || die "cannot inject busybox (missing $BUSYBOX) — this image is a bare zone rootfs, not bootable with systemd-nspawn; try --debootstrap"
  [[ -w "$root" ]] || die "rootfs not writable: $root"
  mkdir -p "$root/sbin" "$root/bin" "$root/etc"
  cp "$BUSYBOX" "$root/sbin/busybox"
  chmod 755 "$root/sbin/busybox"
  ln -sfn busybox "$root/sbin/init"
  [[ -e "$root/bin/sh" || -L "$root/bin/sh" ]] || ln -s ../sbin/busybox "$root/bin/sh"
  [[ -e "$root/bin/ip" || -L "$root/bin/ip" ]] || ln -s ../sbin/busybox "$root/bin/ip"
  cat > "$root/etc/inittab" <<'EOF'
::sysinit:/usr/local/sbin/nspawnctl-net.sh
::respawn:-/bin/sh
EOF
  ### Marker distinguishing a real injection from distros that natively use
  ### busybox (alpine: /sbin/init -> /bin/busybox), read by 'info'
  echo "nspawnctl busybox rescue init" > "$root/etc/nspawnctl-init"
}

### systemd-networkd: unit file + activation symlink (native path).
net_networkd() {
  local root="$1" netfile="$2" static="$3" gw="$4" dns="$5"
  mkdir -p "$root/etc/systemd/network" "$root/etc/systemd/system/multi-user.target.wants"
  cat > "$netfile" <<EOF
[Match]
Name=host0

[Network]
Address=$static/24
Gateway=$gw
DNS=$dns
LinkLocalAddressing=no
EOF
  ln -sfn /usr/lib/systemd/system/systemd-networkd.service \
    "$root/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
}

### ifupdown: rewrite /etc/network/interfaces (backup preserved) and activate
### the networking service via whatever init system is present.
net_ifupdown() {
  local root="$1" static="$2" gw="$3"
  mkdir -p "$root/etc/network"
  [[ -e "$root/etc/network/interfaces.nspawnctl.bak" ]] \
    || mv -f "$root/etc/network/interfaces" "$root/etc/network/interfaces.nspawnctl.bak"
  cat > "$root/etc/network/interfaces" <<EOF
auto lo
iface lo inet loopback

auto host0
iface host0 inet static
    address $static/24
    gateway $gw
EOF
  if [[ -d "$root/etc/runlevels" && -e "$root/etc/init.d/networking" ]]; then
    mkdir -p "$root/etc/runlevels/default"
    ln -sfn ../init.d/networking "$root/etc/runlevels/default/networking"
    info "network: ifupdown enabled via openrc (runlevels/default)"
  elif [[ -d "$root/etc/rcS.d" && -e "$root/etc/init.d/networking" ]]; then
    ln -sfn ../init.d/networking "$root/etc/rcS.d/S01networking"
    info "network: ifupdown enabled via sysvinit (rcS.d)"
  else
    warn "ifupdown interfaces written but no service activator found (openrc/sysvinit)"
  fi
}

### No init-managed network stack: write a busybox ip script and hook it into
### the boot sequence (systemd service / inittab / rc.local / openrc local.d),
### whatever the init system is.
net_script() {
  local root="$1" static="$2" gw="$3"
  local script="/usr/local/sbin/nspawnctl-net.sh"
  mkdir -p "$root/usr/local/sbin"
  cat > "$root$script" <<EOF
#!/bin/sh
ip link set host0 up 2>/dev/null || true
ip addr replace $static/24 dev host0 2>/dev/null || ip addr add $static/24 dev host0 2>/dev/null || true
ip route replace default via $gw 2>/dev/null || true
EOF
  chmod 755 "$root$script"
  if [[ "$(detect_init "$root")" == "systemd" ]]; then
    ### systemd rootfs without systemd-networkd (e.g. openEuler): systemd
    ### ignores /etc/inittab, so hook the script via a oneshot unit instead.
    mkdir -p "$root/etc/systemd/system"
    cat > "$root/etc/systemd/system/nspawnctl-net.service" <<EOF
[Unit]
Description=nspawnctl network setup
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$script

[Install]
WantedBy=multi-user.target
EOF
    mkdir -p "$root/etc/systemd/system/multi-user.target.wants"
    ln -sfn /etc/systemd/system/nspawnctl-net.service \
      "$root/etc/systemd/system/multi-user.target.wants/nspawnctl-net.service"
    info "network: hooked into systemd (oneshot unit nspawnctl-net.service)"
  elif [[ -e "$root/etc/inittab" ]]; then
    grep -q "nspawnctl-net.sh" "$root/etc/inittab" \
      || echo "::sysinit:$script" >> "$root/etc/inittab"
    info "network: hooked into /etc/inittab (sysinit)"
  elif [[ -e "$root/etc/rc.local" ]]; then
    grep -q "nspawnctl-net.sh" "$root/etc/rc.local" \
      || echo "$script" >> "$root/etc/rc.local"
    info "network: hooked into /etc/rc.local"
  elif [[ -d "$root/etc/local.d" && -e "$root/etc/init.d/local" ]]; then
    mkdir -p "$root/etc/runlevels/default"
    ln -sfn "$script" "$root/etc/local.d/nspawnctl-net.start"
    ln -sfn ../init.d/local "$root/etc/runlevels/default/local"
    info "network: hooked into /etc/local.d (openrc)"
  else
    warn "network script written ($script) but no boot hook found — run it manually inside the machine"
  fi
}

### Undo the rootfs-side network artifacts written by net_enable.
remove_net_files() {
  local root="$1"
  rm -f "$root/etc/systemd/network/10-host0.network"
  rm -f "$root/usr/local/sbin/nspawnctl-net.sh"
  rm -f "$root/etc/local.d/nspawnctl-net.start"
  rm -f "$root/etc/systemd/system/nspawnctl-net.service"
  rm -f "$root/etc/systemd/system/multi-user.target.wants/nspawnctl-net.service"
  if [[ -e "$root/etc/network/interfaces.nspawnctl.bak" ]]; then
    mv -f "$root/etc/network/interfaces.nspawnctl.bak" "$root/etc/network/interfaces"
  fi
  if [[ -e "$root/etc/inittab" ]]; then
    grep -v "nspawnctl-net.sh" "$root/etc/inittab" > "$root/etc/inittab.tmp" 2>/dev/null \
      && mv -f "$root/etc/inittab.tmp" "$root/etc/inittab"
    rm -f "$root/etc/inittab.tmp"
  fi
  [[ -e "$root/etc/rc.local" ]] && sed -i '/nspawnctl-net.sh/d' "$root/etc/rc.local" || true
}

### Read the machine IP. machined's IPAddress property works via netlink,
### without systemd inside the machine; nsenter into the machine netns is
### the fallback.
machine_ip() {
  local machine="$1" ip=""
  ip=$(machinectl show "$machine" -p IPAddress 2>/dev/null \
    | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1 || true)
  [[ -n "$ip" ]] && { echo "$ip"; return 0; }
  local leader=""
  leader=$(machinectl show "$machine" -p Leader 2>/dev/null | sed -n 's/^Leader=//p' || true)
  [[ -n "$leader" ]] || return 1
  ip=$(nsenter -t "$leader" -n -- ip -4 addr show host0 2>/dev/null \
    | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1 || true)
  [[ -n "$ip" ]] || return 1
  echo "$ip"
}

### Poll for the machine IP, up to <timeout> seconds.
wait_for_ip() {
  local machine="$1" timeout="${2:-60}" ip="" waited=0
  for _ in $(seq 1 "$timeout"); do
    ip=$(machine_ip "$machine" || true)
    [[ -n "$ip" ]] && { echo "$ip"; return 0; }
    waited=$((waited + 1))
    [[ $((waited % 20)) -eq 0 ]] && warn "... still waiting ($waited/${timeout}s)"
    sleep 1
  done
  return 1
}

### Wire the machine to the systemd-nspawn bridge + static IP + network inside.
### The network setup adapts to the init/network stack detected in the rootfs:
###   systemd-networkd -> unit + activation symlink (native)
###   ifupdown         -> /etc/network/interfaces (backup preserved)
###   none             -> busybox ip script hooked into the boot sequence
### DHCP inside containers is currently broken (networkd client never sends
### DISCOVER), so a stable IP is derived from the machine name unless
### --static <ip> is given.
net_enable() {
  local machine="$1" static="${2:-}"
  local root="$MACHINES_DIR/$machine"
  local dropin="$DROPIN_DIR/$machine.nspawn"
  local netfile="$root/etc/systemd/network/10-host0.network"
  local gw="10.0.5.1" dns="1.1.1.1"

  ensure_init "$root"

  if [[ -z "$static" ]]; then
    local sum
    sum=$(printf '%s' "$machine" | cksum | cut -d' ' -f1)
    static="10.0.5.$((sum % 240 + 10))"
  fi

  mkdir -p "$DROPIN_DIR" "$root/etc"

  cat > "$dropin" <<EOF
[Network]
VirtualEthernet=yes
Bridge=$BRIDGE
EOF

  ### resolv.conf is a symlink in systemd images (e.g.
  ### ../run/systemd/resolve/stub-resolv.conf) whose target directory does not
  ### exist in the freshly extracted rootfs — a direct redirect would follow
  ### the symlink and fail with ENOENT. Write a temp file and move it over the
  ### symlink, replacing it with a regular file.
  cat > "$root/etc/resolv.conf.nspawnctl" <<EOF
nameserver $dns
EOF
  mv -f "$root/etc/resolv.conf.nspawnctl" "$root/etc/resolv.conf"

  case "$(detect_net "$root")" in
    networkd) net_networkd "$root" "$netfile" "$static" "$gw" "$dns" ;;
    ifupdown) net_ifupdown "$root" "$static" "$gw" ;;
    *) net_script "$root" "$static" "$gw" ;;
  esac

  if machinectl status "$machine" >/dev/null 2>&1; then
    info "Restarting $machine to apply network settings..."
    machinectl stop "$machine" \
      || warn "stop reported an error, proceeding anyway"
  fi

  ### Wait for a previous stop to fully settle before starting again
  local stop_timeout="${NSPAWNCTL_STOP_TIMEOUT:-30}"
  local down=0
  for _ in $(seq 1 "$stop_timeout"); do
    if ! machinectl status "$machine" >/dev/null 2>&1; then
      down=1
      break
    fi
    sleep 1
  done

  machinectl start "$machine"

  info "Waiting for $machine to get an IP (up to 60s)..."
  local ip=""
  ip=$(wait_for_ip "$machine" 60 || true)
  if [[ -n "$ip" ]]; then
    ok "machine '$machine' is up: $ip (gateway $gw, DNS $dns)"
  else
    warn "machine '$machine' started but no IP yet — check: machinectl show $machine -p IPAddress"
  fi
}
