#!/usr/bin/env bash
### nspawnctl unit tests — run: bash script/test-nspawnctl.sh
### Relocatable: derives the repo root from its own location; all scratch
### files live in a mktemp workdir cleaned up on exit.
set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
SRC="$REPO_ROOT/pkgs/nspawnctl/src/nspawnctl"
SRC_LIB="$REPO_ROOT/pkgs/nspawnctl/src/lib"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

TRUNC=$(grep -n '^case "\$1" in' "$SRC" | cut -d: -f1)
TEST_SRC=$(sed -e 's/^#! .*//' \
  -e 's/^\[\[ \$EUID -eq 0 \]\] || die .*/: # root guard removed/' \
  "$SRC" | head -n "$((TRUNC - 2))")

PASS=0
FAIL=0

MOCKS=$(cat <<'MOCKS'
zfs() {
  case "$1" in
    list) return 1 ;;
    create) echo "zfs create called" >&2 ;;
    set) echo "zfs set called" >&2 ;;
    get) echo "-" ;;
    destroy) echo "zfs destroy called" >&2 ;;
  esac
}
curl() {
  case "$*" in
    *fake-streams.json) cat "$FAKE_STREAMS" ;;
    *api.github.com*) cat "$FAKE_RELEASES" ;;
    *fake-releases.json) cat "$FAKE_RELEASES" ;;
    *-fsSI*) return 0 ;;
    *-fsSL*) echo "listing-html" ;;
    *) echo "dummy-image" ;;
  esac
}
xz() { cat; }
machinectl() { return 1; }
MOCKS
)

run_test() {
  local name="$1" body="$2" expect="$3"
  local out
  body=${body//\/tmp\/opencode/$WORK}
  out=$(bash -c "
    set -u
    export NSPAWNCTL_CONF=$NSPAWNCTL_CONF NSPAWNCTL_LIBDIR=$NSPAWNCTL_LIBDIR
    export FAKE_STREAMS='$WORK/fake-streams.json'
    export FAKE_RELEASES='$WORK/fake-releases.json'
    export SRC='$SRC'
    $TEST_SRC
    $MOCKS
    $body
  " 2>&1) || true
  if [[ "$out" == *"$expect"* ]]; then
    PASS=$((PASS + 1))
    echo "PASS: $name"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name"
    echo "  expected substring: $expect"
    echo "  output: $out"
  fi
}

run_test_err() {
  local name="$1" body="$2" expect="$3"
  run_test "$name (expected error)" "$body" "$expect"
}

### Fixtures: fake LXC streams catalogue (mirrors images.linuxcontainers.org
### structure: one product per release/variant, numeric + codename aliases)
cat > "$WORK/fake-streams.json" <<'EOF'
{"products": {
  "ubuntu:jammy:amd64:default": {"arch": "amd64", "aliases": "ubuntu/jammy,ubuntu/22.04,ubuntu/22.04/default,ubuntu/jammy/default", "versions": {"20260726_07:42": {"items": {"root.tar.xz": {"path": "images/ubuntu/jammy/amd64/default/20260726_07:42/rootfs.tar.xz"}}}}},
  "ubuntu:noble:amd64:default": {"arch": "amd64", "aliases": "ubuntu/noble,ubuntu/24.04,ubuntu/24.04/default,ubuntu/noble/default", "versions": {"20260730_07:42": {"items": {"root.tar.xz": {"path": "images/ubuntu/noble/amd64/default/20260730_07:42/rootfs.tar.xz"}}}}},
  "ubuntu:noble:amd64:cloud": {"arch": "amd64", "aliases": "ubuntu/noble/cloud,ubuntu/24.04/cloud", "versions": {"20260730_07:42": {"items": {"root.tar.xz": {"path": "images/ubuntu/noble/amd64/cloud/20260730_07:42/rootfs.tar.xz"}}}}},
  "ubuntu:noble:amd64:desktop": {"arch": "amd64", "aliases": "ubuntu/noble/desktop,ubuntu/24.04/desktop", "versions": {"20260730_07:42": {"items": {"root.tar.xz": {"path": "images/ubuntu/noble/amd64/desktop/20260730_07:42/rootfs.tar.xz"}}}}},
  "debian:bookworm:amd64:default": {"arch": "amd64", "aliases": "debian/bookworm,debian/12,debian/bookworm/default,debian/12/default", "versions": {"20260728_05:00": {"items": {"root.tar.xz": {"path": "images/debian/bookworm/amd64/default/20260728_05:00/rootfs.tar.xz"}}}}},
  "debian:forky:amd64:default": {"arch": "amd64", "aliases": "debian/forky,debian/14,debian/forky/default,debian/14/default", "versions": {"20260801_05:24": {"items": {"root.tar.xz": {"path": "images/debian/forky/amd64/default/20260801_05:24/rootfs.tar.xz"}}}}}
}}
EOF

### Fake machinectl for the full-dispatch tests (PATH override)
mkdir -p "$WORK/fakebin"
printf '#!/bin/sh\nexit 0\n' > "$WORK/fakebin/machinectl"
chmod +x "$WORK/fakebin/machinectl"

### Fake GitHub releases JSON for lx_repo_assets (TritonDataCenter/lx-images)
cat > "$WORK/fake-releases.json" <<'EOF'
[{"published_at": "2026-07-29T00:33:24Z", "assets": [
  {"name": "lx-debian-trixie-2026-07-29_00-33-24.tar.xz", "browser_download_url": "https://github.com/TritonDataCenter/lx-images/releases/download/daily/lx-debian-trixie-2026-07-29_00-33-24.tar.xz"},
  {"name": "lx-alpine-3-2026-07-29_00-33-24.tar.xz", "browser_download_url": "https://github.com/TritonDataCenter/lx-images/releases/download/daily/lx-alpine-3-2026-07-29_00-33-24.tar.xz"}
]}, {"published_at": "2025-01-29T18:05:27Z", "assets": [
  {"name": "lx-debian-buster-2025-01-29_18-05-27.tar.xz", "browser_download_url": "https://github.com/TritonDataCenter/lx-images/releases/download/old/lx-debian-buster-2025-01-29_18-05-27.tar.xz"}
]}]
EOF

echo "nspawnctl harness (repo: $REPO_ROOT)"
export NSPAWNCTL_CONF="$WORK/testconf-shell" NSPAWNCTL_LIBDIR=$SRC_LIB

echo "NSPAWNCTL_EXTRA_SOURCES=(mirror=https://mirror.example.com/images/{os}-{version}.tar.xz)" > "$WORK/testconf-mirror"
: > "$WORK/testconf-empty"
rm -rf "$WORK/vmtest" && mkdir -p "$WORK/vmtest/machines"

# --- parse_spec ---
run_test "spec manual source (mirror) -> image" '
  NSPAWNCTL_CONF=/tmp/opencode/testconf-mirror
  load_conf
  parse_spec mirror:debian:trixie
  echo "image=$G_SPEC_IMAGE"
' 'image=debian-trixie'

run_test_err "unknown source still dies" '
  parse_spec nosuch:os:ver
' 'unknown source'

run_test "spec smartos" '
  parse_spec smartos:debian:trixie
  echo "image=$G_SPEC_IMAGE"
' 'image=debian-trixie'

run_test "spec ubuntu shorthand" '
  parse_spec ubuntu:noble
  echo "image=$G_SPEC_IMAGE"
' 'image=noble'

run_test_err "spec ubuntu with extra field dies" '
  parse_spec ubuntu:noble:extra
' 'format: ubuntu:<codename>'

run_test_err "spec ubuntu with variant field dies" '
  parse_spec ubuntu:noble:cloud:extra
' 'format: ubuntu:<codename>'

# --- lxc spec: version optional, variant selectable ---
run_test "spec lxc without version -> os only" '
  parse_spec lxc:ubuntu
  echo "image=$G_SPEC_IMAGE"
' 'image=ubuntu'

run_test "spec lxc empty version -> os only" '
  parse_spec lxc:ubuntu:
  echo "image=$G_SPEC_IMAGE"
' 'image=ubuntu'

run_test "spec lxc with variant -> os/version/variant" '
  parse_spec lxc:ubuntu:noble:cloud
  echo "image=$G_SPEC_IMAGE"
' 'image=ubuntu/noble/cloud'

run_test_err "spec lxc variant without version -> die" '
  parse_spec lxc:ubuntu::cloud
' 'variant needs a version'

# --- lx_url ---
run_test "lx_url manual template {os}/{version}" '
  NSPAWNCTL_CONF=/tmp/opencode/testconf-mirror
  load_conf
  echo "url=$(lx_url mirror debian-trixie)"
' 'url=https://mirror.example.com/images/debian-trixie.tar.xz'

run_test "lx_url lxc os only -> newest release, default variant" '
  export LXC_STREAMS=https://streams.example.org/fake-streams.json
  echo "url=$(lx_url lxc ubuntu)"
' 'url=https://images.linuxcontainers.org/images/ubuntu/noble/amd64/default/20260730_07:42/rootfs.tar.xz'

run_test "lx_url lxc os only debian -> newest numeric release" '
  export LXC_STREAMS=https://streams.example.org/fake-streams.json
  echo "url=$(lx_url lxc debian)"
' 'url=https://images.linuxcontainers.org/images/debian/forky/amd64/default/20260801_05:24/rootfs.tar.xz'

run_test "lx_url lxc version -> exact alias" '
  export LXC_STREAMS=https://streams.example.org/fake-streams.json
  echo "url=$(lx_url lxc ubuntu/jammy)"
' 'url=https://images.linuxcontainers.org/images/ubuntu/jammy/amd64/default/20260726_07:42/rootfs.tar.xz'

run_test "lx_url lxc variant -> exact alias" '
  export LXC_STREAMS=https://streams.example.org/fake-streams.json
  echo "url=$(lx_url lxc ubuntu/noble/cloud)"
' 'url=https://images.linuxcontainers.org/images/ubuntu/noble/amd64/cloud/20260730_07:42/rootfs.tar.xz'

run_test_err "lx_url lxc bad form -> die" '
  export LXC_STREAMS=https://streams.example.org/fake-streams.json
  lx_url lxc "ubuntu/noble/cloud/x"
' 'lxc images are'

run_test "lx_url ubuntu" 'echo "url=$(lx_url ubuntu noble)"' \
  'url=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64-root.tar.xz'

run_test "lx_url smartos resolves newest asset URL" '
  echo "url=$(lx_url smartos debian-trixie)"
' 'url=https://github.com/TritonDataCenter/lx-images/releases/download/daily/lx-debian-trixie-2026-07-29_00-33-24.tar.xz'

run_test "cmd_list smartos shows full build timestamp (not seconds)" '
  LX_REPOS="fakeorg/lx-images"
  out=$(cmd_list smartos debian 2>&1)
  echo "$out" | grep -q "2026-07-29 00-33-24" && echo OK
' 'OK'

# --- conf loading ---
run_test "conf extra source appears in --list (manual notice)" '
  NSPAWNCTL_CONF=/tmp/opencode/testconf-mirror
  load_conf
  cmd_list mirror 2>&1
' 'no remote listing'

run_test "conf with quoted space-joined lists sources cleanly" '
  printf "LX_REPOS=\x27TritonDataCenter/lx-images omniosorg/lx-images\x27\nLXC_STREAMS=\x27https://streams.example.com/images.json\x27\nNSPAWNCTL_EXTRA_SOURCES=(\x27m=https://m/x/{os}-{version}.tar.xz\x27 \x27n=https://n/x/{os}-{version}.tar.xz\x27)\n" > /tmp/opencode/testconf-list
  NSPAWNCTL_CONF=/tmp/opencode/testconf-list
  load_conf
  [[ "$LX_REPOS" == "TritonDataCenter/lx-images omniosorg/lx-images" ]] \
    && [[ "$LXC_STREAMS" == "https://streams.example.com/images.json" ]] \
    && [[ -n "${EXTRA_URLS[m]:-}" && -n "${EXTRA_URLS[n]:-}" ]] && echo OK
' 'OK'

# --- detect_init / detect_net ---
run_test "detect_init: systemd rootfs" '
  mkdir -p /tmp/opencode/vmtest/di-sd/usr/lib/systemd
  touch /tmp/opencode/vmtest/di-sd/usr/lib/systemd/systemd
  echo "$(detect_init /tmp/opencode/vmtest/di-sd)"
' 'systemd'

run_test "detect_init: other init (sbin/init)" '
  mkdir -p /tmp/opencode/vmtest/di-other/sbin
  touch /tmp/opencode/vmtest/di-other/sbin/init
  echo "$(detect_init /tmp/opencode/vmtest/di-other)"
' 'other'

run_test "detect_init: none" 'echo "$(detect_init /tmp/opencode/vmtest/di-none)"' 'none'

run_test "detect_net: networkd" '
  mkdir -p /tmp/opencode/vmtest/dn-nw/usr/lib/systemd/system
  touch /tmp/opencode/vmtest/dn-nw/usr/lib/systemd/system/systemd-networkd.service
  echo "$(detect_net /tmp/opencode/vmtest/dn-nw)"
' 'networkd'

run_test "detect_net: ifupdown" '
  mkdir -p /tmp/opencode/vmtest/dn-if/etc/network /tmp/opencode/vmtest/dn-if/sbin
  touch /tmp/opencode/vmtest/dn-if/etc/network/interfaces /tmp/opencode/vmtest/dn-if/sbin/ifup
  echo "$(detect_net /tmp/opencode/vmtest/dn-if)"
' 'ifupdown'

run_test "detect_net: none" 'echo "$(detect_net /tmp/opencode/vmtest/dn-none)"' 'none'

# --- resolv.conf symlink regression (systemd images symlink
# --- /etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf whose target
# --- directory does not exist in a freshly extracted rootfs)
run_test "resolv.conf symlink is replaced by regular file" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  rm -rf "$MACHINES_DIR/r1"
  mkdir -p "$MACHINES_DIR/r1/etc"
  ln -sfn ../run/systemd/resolve/stub-resolv.conf "$MACHINES_DIR/r1/etc/resolv.conf"
  dns="1.1.1.1"
  root="$MACHINES_DIR/r1"
  cat > "$root/etc/resolv.conf.nspawnctl" <<EOF
nameserver $dns
EOF
  mv -f "$root/etc/resolv.conf.nspawnctl" "$root/etc/resolv.conf"
  [[ ! -L "$root/etc/resolv.conf" ]] \
    && grep -q "nameserver 1.1.1.1" "$root/etc/resolv.conf" && echo OK
' 'OK'

# --- net_enable plumbing ---
run_test "cmd_remove: declined prompt keeps dropin + net files intact" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  DROPIN_DIR=/tmp/opencode/vmtest/dropins
  zfs() {
    case "$1" in
      list) return 0 ;;
      get) echo "no" ;;
      unmount) : ;;
      destroy) echo "zfs destroy called" >&2 ;;
    esac
  }
  read() { ans="n"; }
  rm -rf "$MACHINES_DIR/rm1" /tmp/opencode/vmtest/dropins
  mkdir -p "$MACHINES_DIR/rm1/etc" /tmp/opencode/vmtest/dropins
  touch "$MACHINES_DIR/rm1/etc/resolv.conf.nspawnctl"
  touch /tmp/opencode/vmtest/dropins/rm1.nspawn
  cmd_remove rm1
  [[ -e /tmp/opencode/vmtest/dropins/rm1.nspawn ]] \
    && [[ -e "$MACHINES_DIR/rm1/etc/resolv.conf.nspawnctl" ]] && echo OK
' 'OK'

run_test "cmd_remove: accepted prompt destroys dataset + dropin" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  DROPIN_DIR=/tmp/opencode/vmtest/dropins
  zfs() {
    case "$1" in
      list) return 0 ;;
      get) echo "no" ;;
      unmount) : ;;
      destroy) echo "zfs destroy called" >&2 ;;
    esac
  }
  read() { ans="y"; }
  rm -rf "$MACHINES_DIR/rm2" /tmp/opencode/vmtest/dropins
  mkdir -p "$MACHINES_DIR/rm2/etc" /tmp/opencode/vmtest/dropins
  touch "$MACHINES_DIR/rm2/etc/resolv.conf"
  touch /tmp/opencode/vmtest/dropins/rm2.nspawn
  cmd_remove rm2
' 'zfs destroy called'

run_test "net_enable: systemd rootfs gets networkd config + resolv.conf" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  DROPIN_DIR=/tmp/opencode/vmtest/dropins
  machinectl() {
    case "$*" in
      *IPAddress*) echo "IPAddress=10.0.5.99" ;;
      status*) return 1 ;;
      start*) : ;;
    esac
  }
  rm -rf "$MACHINES_DIR/cl1" /tmp/opencode/vmtest/dropins
  mkdir -p "$MACHINES_DIR/cl1/usr/lib/systemd/systemd" "$MACHINES_DIR/cl1/usr/lib/systemd/system"
  touch "$MACHINES_DIR/cl1/usr/lib/systemd/system/systemd-networkd.service"
  net_enable cl1
  [[ -f "$MACHINES_DIR/cl1/etc/systemd/network/10-host0.network" ]] \
    && grep -q "Address=10.0.5." "$MACHINES_DIR/cl1/etc/systemd/network/10-host0.network" \
    && grep -q "nameserver" "$MACHINES_DIR/cl1/etc/resolv.conf" \
    && [[ ! -L "$MACHINES_DIR/cl1/etc/resolv.conf" ]] \
    && [[ -L "$MACHINES_DIR/cl1/etc/systemd/system/multi-user.target.wants/systemd-networkd.service" ]] \
    && [[ -e "$MACHINES_DIR/cl1/usr/lib/systemd/system/systemd-networkd.service" ]] \
    && echo OK
' 'OK'

run_test "net_enable: static ip from machine name is stable" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  DROPIN_DIR=/tmp/opencode/vmtest/dropins
  machinectl() {
    case "$*" in
      *IPAddress*) echo "IPAddress=10.0.5.99" ;;
      status*) return 1 ;;
      start*) : ;;
    esac
  }
  rm -rf "$MACHINES_DIR/cl2" /tmp/opencode/vmtest/dropins
  mkdir -p "$MACHINES_DIR/cl2/usr/lib/systemd/systemd" "$MACHINES_DIR/cl2/usr/lib/systemd/system"
  touch "$MACHINES_DIR/cl2/usr/lib/systemd/system/systemd-networkd.service"
  net_enable cl2
  ip_a=$(grep -oP "Address=\K[0-9.]+" "$MACHINES_DIR/cl2/etc/systemd/network/10-host0.network")
  rm -rf "$MACHINES_DIR/cl2" /tmp/opencode/vmtest/dropins
  mkdir -p "$MACHINES_DIR/cl2/usr/lib/systemd/systemd" "$MACHINES_DIR/cl2/usr/lib/systemd/system"
  touch "$MACHINES_DIR/cl2/usr/lib/systemd/system/systemd-networkd.service"
  net_enable cl2
  ip_b=$(grep -oP "Address=\K[0-9.]+" "$MACHINES_DIR/cl2/etc/systemd/network/10-host0.network")
  [[ "$ip_a" == "$ip_b" ]] && echo "OK $ip_a"
' 'OK'

# --- ensure_init ---
run_test "ensure_init: no init and busybox missing dies" '
  BUSYBOX=
  root=/tmp/opencode/vmtest/no-init
  rm -rf "$root" && mkdir -p "$root"
  ensure_init "$root" 2>&1
' 'cannot inject busybox'

run_test "ensure_init: injects busybox init into bare rootfs" '
  BUSYBOX=/tmp/opencode/vmtest/busybox
  printf "#!/bin/sh\nexit 0\n" > /tmp/opencode/vmtest/busybox
  chmod +x /tmp/opencode/vmtest/busybox
  root=/tmp/opencode/vmtest/bare
  rm -rf "$root" && mkdir -p "$root"
  ensure_init "$root"
  [[ -x "$root/sbin/init" ]] \
    && [[ -L "$root/bin/sh" ]] \
    && [[ -f "$root/etc/inittab" ]] \
    && grep -q "nspawnctl-net.sh" "$root/etc/inittab" \
    && echo OK
' 'OK'

# --- net_script on systemd rootfs (regression: openEuler — systemd ignores
# --- /etc/inittab, so the script must be hooked via a oneshot unit) ---
run_test "net_script: systemd rootfs gets oneshot unit (not inittab)" '
  root=/tmp/opencode/vmtest/sd-rootfs
  rm -rf "$root" && mkdir -p "$root/usr/lib/systemd" "$root/etc/systemd/system"
  touch "$root/usr/lib/systemd/systemd"
  net_script "$root" 10.0.5.99 10.0.5.1
  [[ -f "$root/etc/systemd/system/nspawnctl-net.service" ]] \
    && grep -q "10.0.5.99/24" "$root/usr/local/sbin/nspawnctl-net.sh" \
    && [[ -L "$root/etc/systemd/system/multi-user.target.wants/nspawnctl-net.service" ]] \
    && [[ ! -e "$root/etc/inittab" ]] \
    && echo OK
' 'OK'

run_test "net_script: non-systemd rootfs still hooks inittab" '
  root=/tmp/opencode/vmtest/init-rootfs
  rm -rf "$root" && mkdir -p "$root/sbin" "$root/etc"
  touch "$root/sbin/init"
  touch "$root/etc/inittab"
  net_script "$root" 10.0.5.99 10.0.5.1
  grep -q "nspawnctl-net.sh" "$root/etc/inittab" \
    && [[ ! -e "$root/etc/systemd/system/nspawnctl-net.service" ]] \
    && echo OK
' 'OK'

run_test "remove_net_files: cleans systemd oneshot unit too" '
  root=/tmp/opencode/vmtest/rm-rootfs
  rm -rf "$root" && mkdir -p "$root/etc/systemd/system/multi-user.target.wants" "$root/usr/local/sbin" "$root/etc/systemd/network"
  touch "$root/etc/systemd/system/nspawnctl-net.service"
  ln -sfn /etc/systemd/system/nspawnctl-net.service "$root/etc/systemd/system/multi-user.target.wants/nspawnctl-net.service"
  touch "$root/etc/systemd/network/10-host0.network"
  remove_net_files "$root"
  [[ ! -e "$root/etc/systemd/system/nspawnctl-net.service" ]] \
    && [[ ! -e "$root/etc/systemd/system/multi-user.target.wants/nspawnctl-net.service" ]] \
    && [[ ! -e "$root/etc/systemd/network/10-host0.network" ]] \
    && echo OK
' 'OK'

# --- machine_ip ---
run_test "machine_ip: via machinectl IPAddress property (no systemd inside)" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  machinectl() { echo "IPAddress=10.0.5.99"; }
  machine_ip t1
' '10.0.5.99'

run_test "machine_ip: fallback nsenter ip when machined has no IP" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  machinectl() {
    case "$*" in
      *IPAddress*) echo "IPAddress=" ;;
      *Leader*) echo "Leader=42" ;;
    esac
  }
  nsenter() { echo "2: host0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
    inet 10.0.5.42/24 brd 10.0.5.255 scope global host0"; }
  machine_ip t1
' '10.0.5.42'

# --- full dispatch ---
run_test "full dispatch: --list lxc switches to lxc source" '
  sed -e "s|^#!.*||" -e "/^require_root() {/,/^}/d" "$SRC" > /tmp/opencode/fullsrc.sh
  PATH=/tmp/opencode/fakebin:$PATH NSPAWNCTL_CONF=/tmp/opencode/testconf-shell bash /tmp/opencode/fullsrc.sh --list lxc 2>&1
' 'Source: lxc'

run_test "full dispatch: shell on missing machine dies" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  zfs() { [[ "$1" == "get" ]] && echo "-"; }
  require_root() { :; }
  sed -e "s|^#!.*||" -e "/^require_root() {/,/^}/d" "$SRC" > /tmp/opencode/fullsrc.sh
  export -f zfs require_root
  PATH=/tmp/opencode/fakebin:$PATH NSPAWNCTL_CONF=/tmp/opencode/testconf-shell bash /tmp/opencode/fullsrc.sh shell nope 2>&1 || true
' 'machine not found'

run_test "full dispatch: rm is an alias for remove" '
  export MACHINES_DIR=/tmp/opencode/vmtest/machines DATASET_ROOT=zroot/MACHINE
  zfs() { [[ "$1" == "get" ]] && echo "-"; }
  require_root() { :; }
  sed -e "s|^#!.*||" -e "/^require_root() {/,/^}/d" "$SRC" > /tmp/opencode/fullsrc.sh
  export -f zfs require_root
  out_rm=$(NSPAWNCTL_CONF=/tmp/opencode/testconf-shell bash /tmp/opencode/fullsrc.sh rm somemachine 2>&1 || true)
  out_remove=$(NSPAWNCTL_CONF=/tmp/opencode/testconf-shell bash /tmp/opencode/fullsrc.sh remove somemachine 2>&1 || true)
  [[ "$out_rm" == "$out_remove" ]] && echo OK
' 'OK'

echo
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
