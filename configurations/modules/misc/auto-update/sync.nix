# configurations/modules/misc/auto-update/sync.nix — channel synchronisation,
# flake inputs and system rebuild (the network/build half; state machine in
# transaction.nix).
#
# Contract (functions exported; globals set: SRC_ID, FLAKE, LOCK_HASH):
#   _check_disk_space              — _fail disk-space below cfg.minDiskGB on /nix/store
#   _check_internet_once / _wait_for_internet [MAXWAIT=600] [RETRY=10]
#                                — curl cache.nixos.org loop, _fail network-offline
#   _mirror_usable GIT_URL         — 0 iff $WORKDIR/flake is a healthy clone of GIT_URL
#   _force_sync_mirror GIT_URL     — fetch --force + reset --hard + clean +
#                                    verify rev==SRC_ID and flake.lock present
#   _fresh_clone GIT_URL           — clone --depth 1 --no-tags into flake.new,
#                                    verify rev, atomic mv into place
#   _sync_channel_clone            — reuse | force-sync | fresh clone; sets
#                                    SRC_ID, FLAKE=$WORKDIR/flake; _fail
#                                    channel-resolve / flake-sync /
#                                    flake-lock-missing
#   _run_flake_update_once / _update_flake_inputs
#                                — nix flake update with retries, _fail flake-update
#   _run_nixos_build / _install_boot_configuration / _rebuild_system
#                                — build, boot-install (attempt-counted by the
#                                  caller via _attempt_boot_installation), nvd diff
#
# Callers must set before use: WORKDIR, FLAKE (init: remote ref),
# AUTO_UPDATE_NIX_LOG_FORMAT (via _init_output), REBUILD_BUILD_TIMEOUT_ENABLED.
{ cfg, repo }:

let
  channel = cfg.channel;
in
''
  # >>>BEGIN sync
  _check_disk_space() {
    local min_space_gb=${toString cfg.minDiskGB}
    local available_kb
    local available_gb

    available_kb=$(df /nix/store | awk 'NR==2 {print $4}')
    available_gb=$((available_kb / 1024 / 1024))

    if [ "$available_gb" -lt "$min_space_gb" ]; then
      _fail disk-space "$available_gb < $min_space_gb"
    fi

    _status INFO "Disk space OK: $available_gb GB available"
  }

  _check_internet_once() {
    curl \
      --connect-timeout 10 \
      --max-time 20 \
      --fail \
      --location \
      --silent \
      --output /dev/null \
      "https://cache.nixos.org/nix-cache-info"
  }

  _wait_for_internet() {
    local max_wait="''${1:-${toString cfg.timeouts.internetWait}}"
    local retry_delay="''${2:-10}"
    local wait_started_at
    local internet_available=0
    local wait_elapsed

    _status INFO "Waiting for internet connectivity (max $max_wait sec)..."
    wait_started_at=$(date +%s)
    while true; do
      if _check_internet_once; then
        _status INFO "Internet connectivity is available."
        internet_available=1
        break
      fi

      wait_elapsed=$(($(date +%s) - wait_started_at))
      [ "$wait_elapsed" -ge "$max_wait" ] && break
      _status WAIT "Still no internet... waited $wait_elapsed sec"
      sleep "$retry_delay"
    done

    if [ "$internet_available" -ne 1 ]; then
      _fail network-offline
    fi
  }

  _mirror_usable() {
    local git_url="$1"

    [ -d "$WORKDIR/flake/.git" ] || return 1
    [ "$(git -C "$WORKDIR/flake" remote get-url origin 2>/dev/null || true)" = "$git_url" ] || return 1
    git -C "$WORKDIR/flake" rev-parse --verify HEAD >/dev/null 2>&1 || return 1
  }

  _force_sync_mirror() {
    local git_url="$1"

    timeout \
      --signal=TERM \
      --kill-after=1m \
      "${cfg.timeouts.fetch}" \
      git -C "$WORKDIR/flake" fetch --force --depth 1 --update-shallow --atomic --no-tags \
      origin "+refs/heads/${channel}:refs/remotes/origin/${channel}" \
      2>&1 | _filter_git_progress || return 1
    git -C "$WORKDIR/flake" reset --hard "origin/${channel}" || return 1
    git -C "$WORKDIR/flake" clean -fdx || return 1
    [ "$(git -C "$WORKDIR/flake" rev-parse HEAD)" = "$SRC_ID" ] || return 1
    [ -f "$WORKDIR/flake/flake.lock" ] || return 1
    git -C "$WORKDIR/flake" reflog expire --expire=now --all 2>/dev/null || true
    git -C "$WORKDIR/flake" gc --prune=now 2>/dev/null || true
    return 0
  }

  _fresh_clone() {
    local git_url="$1"
    local clone_tmp="$WORKDIR/flake.new"

    rm -rf -- "$clone_tmp"
    timeout \
      --signal=TERM \
      --kill-after=1m \
      "${cfg.timeouts.clone}" \
      git clone --depth 1 --no-tags --branch "${channel}" "$git_url" "$clone_tmp" \
      2>&1 | _filter_git_progress || return 1
    [ "$(git -C "$clone_tmp" rev-parse HEAD 2>/dev/null || true)" = "$SRC_ID" ] || return 1
    # Verified content only: drop the previous tree (if any), then move the
    # new one into place atomically. A crash between the two leaves no tree
    # at all, which the next run heals with a fresh clone.
    rm -rf -- "$WORKDIR/flake"
    mv -T -- "$clone_tmp" "$WORKDIR/flake"
    sync -f "$WORKDIR" || true
    return 0
  }

  _sync_channel_clone() {
    local git_url="''${AUTO_UPDATE_GIT_URL:-${repo.gitUrl}}"

    SRC_ID=$(timeout \
      --signal=TERM \
      --kill-after=30s \
      "${cfg.timeouts.lsRemote}" \
      git ls-remote "$git_url" "refs/heads/${channel}" | cut -f1) || _fail channel-resolve
    [ -n "$SRC_ID" ] || _fail channel-resolve

    if [ -d "$WORKDIR/flake/.git" ] \
      && [ "$(git -C "$WORKDIR/flake" rev-parse HEAD 2>/dev/null || true)" = "$SRC_ID" ]; then
      _status INFO "Channel still at $SRC_ID, reusing previous clone."
    elif _mirror_usable "$git_url"; then
      _status INFO "Force-syncing channel @ $SRC_ID."
      if ! _force_sync_mirror "$git_url"; then
        _status WARNING "Incremental sync failed, falling back to fresh clone."
        _fresh_clone "$git_url" || _fail flake-sync
      fi
    else
      _status INFO "Cloning channel @ $SRC_ID."
      _fresh_clone "$git_url" || _fail flake-sync
    fi
    FLAKE="$WORKDIR/flake"
    [ -f "$FLAKE/flake.lock" ] || _fail flake-lock-missing
  }

  _run_flake_update_once() {
    timeout \
      --signal=TERM \
      --kill-after=5m \
      "${cfg.timeouts.flakeUpdate}" \
      nix flake update \
      --flake "$FLAKE" \
      --log-format "$AUTO_UPDATE_NIX_LOG_FORMAT" 2>&1 | _filter_git_progress | _monitor_nix_output | _prefix_lines INFO
  }

  _update_flake_inputs() {
    local max_retries=3
    local retry_delay=60
    local flake_update_ok=0
    local attempt

    _status INFO "Starting flake update for $FLAKE"
    for attempt in $(seq 1 "$max_retries"); do
      _status INFO "Resolving flake inputs (attempt $attempt/$max_retries)..."
      if _run_flake_update_once; then
        flake_update_ok=1
        break
      fi
      _status WARNING "Flake update failed (try $attempt/$max_retries), retrying in $retry_delay sec..."
      [ "$attempt" -lt "$max_retries" ] && sleep "$retry_delay"
    done

    if [ "$flake_update_ok" -eq 0 ]; then
      _fail flake-update
    fi
  }

  _run_nixos_build() {
    local nixos_label_env=()
    if [ "$DEBUG_MODE" -eq 1 ]; then
      nixos_label_env=(NIXOS_LABEL=debug)
      _debug "Debug mode: generation will be labeled 'debug'"
    fi

    if [ "$REBUILD_BUILD_TIMEOUT_ENABLED" -eq 0 ]; then
      "''${nixos_label_env[@]}" nixos-rebuild build \
        --flake "$FLAKE#${cfg.configuration}" \
        --log-format "$AUTO_UPDATE_NIX_LOG_FORMAT"
      return $?
    fi

    "''${nixos_label_env[@]}" timeout \
      --signal=TERM \
      --kill-after=1m \
      "${cfg.timeouts.build}" \
      nixos-rebuild build \
      --flake "$FLAKE#${cfg.configuration}" \
      --log-format "$AUTO_UPDATE_NIX_LOG_FORMAT"
  }

  _install_boot_configuration() {
    local command_status=0
    local renderer_status=0
    local pipeline_status="0 0 0"
    local nixos_label_env=()

    if [ "$DEBUG_MODE" -eq 1 ]; then
      nixos_label_env=(NIXOS_LABEL=debug)
    fi

    _status INFO "Installing the validated system as the next boot generation..."
    if "''${nixos_label_env[@]}" timeout \
      --signal=TERM \
      --kill-after=1m \
      "${cfg.timeouts.boot}" \
      nixos-rebuild boot \
      --flake "$FLAKE#${cfg.configuration}" \
      --print-build-logs \
      --log-format "$AUTO_UPDATE_NIX_LOG_FORMAT" 2>&1 | _monitor_nix_output | _prefix_lines INFO; then
      pipeline_status="0 0 0"
    else
      pipeline_status="''${PIPESTATUS[@]}"
    fi
    command_status=$(echo "$pipeline_status" | cut -d' ' -f1)
    renderer_status=$(echo "$pipeline_status" | cut -d' ' -f2)
    # pipeline_status[2] is the logging-only prefix loop; its failure is
    # noise, the producer statuses above decide.

    if [ "$renderer_status" -ne 0 ]; then
      _status WARNING "The output renderer failed; the boot installation result is unaffected."
    fi
    if [ "$command_status" -ne 0 ]; then
      return 1
    fi
  }

  _nvd_diff_profile() {
    # Package summary between the previous profile generation and the staged
    # profile. Same generation resolution as the report-changes activation
    # hook (configurations/configs/common/system-opts/system-settings.nix):
    # the generation before `(current)` in `nix-env --list-generations`.
    # Incremental by design: if a generation was staged without rebooting,
    # only the delta since that staged generation is shown (already-notified
    # changes are not repeated). The hook's initrd/first-install guards do
    # not apply here — this service only runs on booted systems.
    local current_profile="$SYSTEM_PROFILE"
    local old_generation="" old_system="" new_system=""

    new_system=$(readlink -f "$current_profile" 2>/dev/null || true)
    if [ -z "$new_system" ]; then
      _status WARNING "Unable to resolve the staged system profile; skipping package summary."
      return 0
    fi
    old_generation=$(nix-env --list-generations -p "$current_profile" 2>/dev/null \
      | awk '/\(current\)/{print prev} {prev=$1}')
    if [ -z "$old_generation" ]; then
      _status INFO "No previous generation found; skipping package summary."
      return 0
    fi
    old_system=$(readlink -f "$current_profile-$old_generation-link" 2>/dev/null || true)
    if [ -z "$old_system" ]; then
      _status WARNING "Unable to resolve previous generation $old_generation; skipping package summary."
      return 0
    fi
    if [ "$old_system" = "$new_system" ]; then
      _status INFO "Staged profile matches the previous generation; no package changes."
      return 0
    fi

    # nvd is deliberately not wrapped in a pseudo-terminal: PTY carriage
    # returns can corrupt the persistent log when they redraw a line.
    # Its output goes through the uniform prefix (service PID everywhere).
    if [ "$INTERACTIVE_OUTPUT" -eq 1 ]; then
      nvd --color always diff "$old_system" "$new_system" 2>&1 | _prefix_lines INFO || \
        _status WARNING "Unable to display the package change summary."
    else
      nvd diff "$old_system" "$new_system" 2>&1 | _prefix_lines INFO || \
        _status WARNING "Unable to display the package change summary."
    fi
  }

  _rebuild_system() {
    # The service runs as root, so nh cannot be used: it deliberately
    # refuses root execution. Progress comes from nom, the package summary
    # from nvd.
    _status INFO "Validating and building the new system configuration..."
    if ! _run_nixos_build 2>&1 | _monitor_nix_output | _prefix_lines INFO; then
      return 1
    fi

    _set_transaction_phase "applying"
    if ! _attempt_boot_installation; then
      if _transaction_profile_advanced; then
        _preserve_transaction_for_recovery
      fi
      return 1
    fi

    _status INFO "Package changes:"
    _nvd_diff_profile
  }
  # <<<END sync
''
