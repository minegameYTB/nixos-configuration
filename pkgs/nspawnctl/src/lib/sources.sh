### Sources: image catalogs, URL resolution, spec parsing, --list.
### Sourced by the nspawnctl entry point — never executed directly.

### Collect every lx-*.tar.xz asset across all releases of a repo:
### <name>\t<published_at>\t<browser_download_url>, newest releases first.
### The daily "latest" release only carries freshly rebuilt images, so the
### whole release history must be scanned to see the full catalog.
lx_repo_assets() {
  local repo="$1" page=1 json n
  while :; do
    json=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=100&page=$page") || break
    n=$(jq length <<<"$json")
    [[ "$n" -eq 0 ]] && break
    jq -r '.[] | .published_at as $p | .assets[]? | select(.name | startswith("lx-") and endswith(".tar.xz")) | "\(.name)\t\($p)\t\(.browser_download_url)"' <<<"$json"
    [[ "$n" -lt 100 ]] && break
    page=$((page + 1))
  done
}

### Resolve the download URL for <image> from the given <source> catalog
lx_url() {
  local source="$1" image="$2" url repo

  case "$source" in
    smartos)
      [[ "$image" =~ ^[a-z0-9-]+$ ]] || die "smartos images are 'distro-release', e.g. debian-trixie (got: '$image')"
      for repo in $LX_REPOS; do
        url=$(lx_repo_assets "$repo" | awk -F'\t' -v p="lx-$image-" 'index($1, p) == 1 { print $3; exit }')
        [[ -n "$url" ]] && { echo "$url"; return 0; }
      done
      die "no asset matching '$image' from source 'smartos' (tried: $LX_REPOS)"
      ;;
    lxc)
      ### Image forms: "os", "os/release", "os/release/variant". Without a
      ### release the newest one is picked (numeric versions win, then
      ### codenames); "default" is preferred over cloud/desktop variants.
      [[ "$image" =~ ^[a-z0-9]+(/[a-z0-9.]+){0,2}$ ]] \
        || die "lxc images are '<distro>[/<release>[/<variant>]]', e.g. debian/trixie or ubuntu/noble/cloud (got: '$image')"
      if [[ "$image" == */* ]]; then
        url=$(curl -fsSL "$LXC_STREAMS" \
          | jq -r --arg a "$image" '
              [.products | to_entries[]
               | select(.value.arch == "amd64")
               | select((.value.aliases | split(",") | index($a)) != null)
               | .value.versions | to_entries[]
               | {key, path: ((.value.items["root.tar.xz"].path // .value.items["rootfs.tar.xz"].path) // null)}]
              | sort_by(.key) | reverse | .[0] | select(.path != null) | .path')
      else
        url=$(curl -fsSL "$LXC_STREAMS" \
          | jq -r --arg a "$image" '
              . as $doc
              | [.products | to_entries[]
                 | select(.value.arch == "amd64")
                 | .key as $key | .value as $v
                 | ($v.aliases | split(",")) as $aliases
                 | select(any($aliases[]; startswith($a + "/")))
                 | {key: $key,
                    variant: ($key | split(":") | .[3]),
                    num: ([$aliases[] | select(test("^" + $a + "/[0-9.]+(/|$)"))] | if length > 0 then (.[0] | ltrimstr($a + "/") | split("/") | .[0]) else null end),
                    codename: ([$aliases[] | select(test("^" + $a + "/[a-z]+(/|$)"))] | if length > 0 then (.[0] | ltrimstr($a + "/") | split("/") | .[0]) else null end)}
                 | .release = (if .num != null then (.num | split(".") | map(tonumber))
                               elif .codename != null then .codename
                               else ($key | split(":") | .[1]) end)
                 | .build = ($doc.products[.key].versions | keys | sort | .[-1])
                 | .path = $doc.products[.key].versions[.build].items["root.tar.xz"].path // $doc.products[.key].versions[.build].items["rootfs.tar.xz"].path
                 | .]
              | sort_by([if (.release | type) == "array" then 0 else 1 end, .release, (.variant == "default"), .build])
              | .[-1] | select(.path != null) | .path')
      fi
      [[ -n "$url" ]] || die "no lxc image '$image' (try: nspawnctl --list --source lxc)"
      echo "https://images.linuxcontainers.org/$url"
      ;;
    ubuntu)
      [[ "$image" =~ ^[a-z0-9]+$ ]] || die "ubuntu images are codenames, e.g. noble (got: '$image')"
      echo "$UBUNTU_CLOUD/$image/current/$image-server-cloudimg-amd64-root.tar.xz"
      ;;
    *)
      # manual source from /etc/nspawnctl.conf: URL template with {os} and {version}
      local tmpl="${EXTRA_URLS[$source]:-}"
      [[ -n "$tmpl" ]] || die "unknown source: $source (available: $LX_SOURCES)"
      local os="${image%%-*}" ver="${image#*-}"
      [[ -n "$os" && -n "$ver" && "$os" != "$ver" ]] \
        || die "format: $source:<os>:<version> (manual source, URL template)"
      url="${tmpl//\{os\}/$os}"
      url="${url//\{version\}/$ver}"
      echo "$url"
      ;;
  esac
}

### Parse "<source>:<os>:<version>" into G_SPEC_SOURCE and G_SPEC_IMAGE (globals, visible to tests)
parse_spec() {
  local spec="$1" os="" version="" variant=""
  local -a parts=()
  IFS=':' read -r -a parts <<< "$spec"
  G_SPEC_SOURCE="${parts[0]:-}"
  [[ " $LX_SOURCES " == *" $G_SPEC_SOURCE "* ]] || die "unknown source: $G_SPEC_SOURCE (available: $LX_SOURCES)"
  os="${parts[1]:-}"
  version="${parts[2]:-}"
  case "$G_SPEC_SOURCE" in
    smartos)
      [[ -n "$os" && -n "$version" ]] || die "format: smartos:<os>:<version>, e.g. smartos:debian:trixie"
      G_SPEC_IMAGE="$os-$version"
      ;;
    lxc)
      ### lxc:<os>[:<version>[:<variant>]] — version optional (newest picked
      ### by lx_url), variant one of default/cloud/desktop (default implied).
      [[ -n "$os" ]] || die "format: lxc:<os>[:<version>[:<variant>]], e.g. lxc:debian:trixie or lxc:ubuntu:noble:cloud"
      variant="${parts[3]:-}"
      [[ -n "$version" ]] || [[ -z "$variant" ]] \
        || die "a variant needs a version: lxc:$os:<version>:$variant"
      G_SPEC_IMAGE="$os"
      if [[ -n "$version" ]]; then
        G_SPEC_IMAGE="$os/$version"
      fi
      if [[ -n "$variant" ]]; then
        G_SPEC_IMAGE="$os/$version/$variant"
      fi
      ;;
    ubuntu)
      [[ -z "$version" && -z "${parts[3]:-}" ]] \
        || die "format: ubuntu:<codename>, e.g. ubuntu:noble (no version or variant allowed)"
      G_SPEC_IMAGE="${version:-$os}"
      [[ -n "$G_SPEC_IMAGE" ]] || die "format: ubuntu:<codename>, e.g. ubuntu:noble"
      ;;
    *)
      # manual source from /etc/nspawnctl.conf (rootfs tarball, like smartos)
      [[ -n "$os" && -n "$version" ]] || die "format: $G_SPEC_SOURCE:<os>:<version>, e.g. $G_SPEC_SOURCE:debian:trixie"
      G_SPEC_IMAGE="$os-$version"
      ;;
  esac
}

### List available images (image, version/build date, release date)
cmd_list() {
  local source="$1" filter="${2:-}"
  local repo json out line count=0

  if [[ "$source" == "all" ]]; then
    local s
    for s in $LX_SOURCES; do
      cmd_list "$s" "$filter"
    done
    return 0
  fi

  case "$source" in
    smartos)
      for repo in $LX_REPOS; do
        echo "Repository: $repo"
        printf '%-22s %-20s %s\n' "IMAGE" "VERSION (build)" "RELEASED"
        out=$(lx_repo_assets "$repo" | sort -r | awk -v f="$filter" '
            {
              name=$1; sub(/^lx-/, "", name);
              sub(/-[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\.tar\.xz$/, "", name);
              if (f != "" && index(name, f) == 0) next;
              if (seen[name]++) next;
              ver=$1; if (match(ver, /[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}/)) { ver=substr(ver, RSTART, RLENGTH) }; gsub(/_/, " ", ver);
              pub=$2; sub(/T.*/, "", pub);
              printf "%-22s %-20s %s\n", name, ver, pub;
              n++;
            }
            END { if (n > 0) printf "(%d images)\n", n; else exit 1 }
          ') || true
        [[ -n "$out" ]] && { echo "$out"; return 0; }
      done
      if [[ -n "$filter" ]]; then
        die "no image matching filter '$filter' from source 'smartos' (tried: $LX_REPOS)"
      fi
      die "no lx-images release found (tried: $LX_REPOS)"
      ;;
    lxc)
      json=$(curl -fsSL "$LXC_STREAMS")
      echo "Source: lxc (images.linuxcontainers.org, amd64)"
      printf '%-32s %-18s\n' "IMAGE" "VERSION"
      while read -r line; do
        [[ -z "$line" ]] && continue
        [[ -z "$filter" || "$line" == *"$filter"* ]] || continue
        echo "$line"
        count=$((count + 1))
      done < <(jq -r --arg f "$filter" '
          [.products | to_entries[]
           | select(.value.arch == "amd64")
           | {aliases: (.value.aliases | split(",")), version: (.value.versions | keys | sort | .[-1])}
           | {name: ((.aliases | map(select(. | test("^[^/]+/[^/]+$"))) | .[0]) // (.aliases | .[0])), version}]
          | map(select(.name != null and .name != ""))
          | unique_by(.name) | sort_by(.name)
          | .[] | "\(.name) \(.version)"' <<<"$json")
      [[ $count -gt 0 ]] && echo "($count images)" || echo "(no images)"
      ;;
    ubuntu)
      local skip="daily|docs|locator|minimal|oci|releases|server|vagrant|wsl"
      echo "Source: ubuntu (cloud-images.ubuntu.com)"
      printf '%-16s %s\n' "CODENAME" "URL"
      while read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^($skip)$ ]] && continue
        [[ -z "$filter" || "$line" == *"$filter"* ]] || continue
        printf '%-16s %s/current/%s-server-cloudimg-amd64-root.tar.xz\n' "$line" "$UBUNTU_CLOUD/$line" "$line"
        count=$((count + 1))
      done < <(curl -fsSL "$UBUNTU_CLOUD/" | grep -oP 'href="[a-z]+/"' | sed -E 's/href="([a-z]+)\/"/\1/' | sort -u)
      [[ $count -gt 0 ]] && echo "($count releases)" || echo "(no releases)"
      ;;
    *)
      if [[ -n "${EXTRA_URLS[$source]:-}" ]]; then
        echo "Source: $source (manual, from $CONF — no remote listing; try 'new $source:<os>:<version>')"
        return 0
      fi
      die "unknown source: $source (available: $LX_SOURCES)"
      ;;
  esac
}
