{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system.autoUpdate;

  ### Single source for the service state dir (StateDirectory + scripts).
  stateDir = "nixos-auto-update";

  ### github:owner/repo derived from the canonical https URL — lib/repo.nix
  ### stays the single source of truth for the repo location.
  repoSlug = lib.removePrefix "https://github.com/" (import ../../../lib/repo.nix).url;

  ### Real desktop = GNOME actually enabled, not just marker.hostProfile.
  ### Notifications are only attempted in that case (plus an active graphical
  ### session checked at runtime) — servers stay journal-only.
  hasRealDesktop = config.services.desktopManager.gnome.enable;
in
{
  options.system.autoUpdate = {
    enable = lib.mkEnableOption "automatic system updates from a channel branch (GLF-OS style)";

    channel = lib.mkOption {
      type = lib.types.str;
      default = "flake-autoupdate";
      description = "Channel branch followed by auto-update: the last soaked-green source commit (pure mirror pointer), not the local .branch.";
    };

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "github:${repoSlug}?ref=${cfg.channel}";
      description = "Remote flake reference used when no usable local checkout exists. Defaults to the channel on GitHub.";
    };

    localCheckout = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/nixos-config";
      description = "Optional local git checkout. When set, existing, and clean on the channel branch, it is pulled (--ff-only) and rebuilt instead of the remote ref. Any problem falls back to flakeRef with a warning.";
    };

    configuration = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "vm-cli-efi";
      description = "Flake attribute to build (nixosConfigurations.<name>). Must be set when enable is true — it intentionally differs from networking.hostName.";
    };

    updateInputs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Bump flake inputs (nix flake update) before rebuilding. Off by default: machines build the channel tree as-is, like an OSTree client — opt in only to trial fresher inputs locally.";
    };

    checkInterval = lib.mkOption {
      type = lib.types.str;
      default = "2d";
      description = "How often to check for updates (systemd monotonic OnUnitInactiveSec). Wall-clock drifting is intended — updates spread themselves.";
    };

    startDelay = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "Delay after boot before the first check (systemd OnBootSec).";
    };

    randomizedDelay = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "RandomizedDelaySec for the update timer (spread a fleet).";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically reboot when the new generation changes kernel or init.";
    };

    notify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Desktop notification on success/failure. Only effective with a real DE installed and an active graphical session; otherwise journal-only.";
    };

    notifyIcon = lib.mkOption {
      type = lib.types.str;
      default = "nix-snowflake-white";
      description = "Icon name for desktop notifications (hicolor theme, shown with the title by the shell).";
    };

    notifyTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10000;
      description = "Notification display time in milliseconds (-t). Honored by most servers; GNOME caps custom timeouts (only critical persists).";
    };

    healthCheck = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Validate staged generations after boot (healthcheck service).";
      };

      units = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default =
          if config.marker.hostProfile == "desktop" then
            [ "display-manager.service" ]
          else
            [ "sshd.service" ];
        example = [
          "sshd.service"
          "NetworkManager.service"
        ];
        description = "Systemd units that must be active after a staged boot. Overridable per machine.";
      };

      requireNetwork = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Require a default IPv4 route after a staged boot.";
      };

      checkFailedUnits = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Fail validation when any unit is in failed state after a staged boot (essential-boot signal).";
      };

      timeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Per-check budget in seconds (service TimeoutStartSec adds a minute).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configuration != null && cfg.configuration != "";
        message = "system.autoUpdate.configuration must be set to a nixosConfigurations attribute (e.g. \"vm-cli-efi\") when system.autoUpdate.enable is true.";
      }
    ];

    systemd.services.nixos-auto-update = {
      description = "Automatic system update from channel ${cfg.channel}";

      unitConfig = {
        ### Network is mandatory (fetch channel + substituters).
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];

        ### Bootloader writes must land on the mounted ESP, never on a
        ### stale /boot dir — order after it (harmless where /boot is no
        ### separate mount: requires the parent mount instead).
        RequiresMountsFor = [ "/boot" ];

        ### Laptops: never update on battery.
        ConditionACPower = true;
      };

      ### Low I/O + CPU priority: updates must never disturb the running system.
      ### NO mount-namespacing sandbox here (ProtectSystem/PrivateTmp/...):
      ### this service drives nix builds, and the nix sandbox needs its own
      ### user+mount namespaces — nesting it inside a systemd sandbox fails
      ### with "VFS: Mount too revealing" / "no kernel namespaces" (seen in
      ### prod). Confinement stays on: restrictive PATH + low priority +
      ### ConditionACPower. (Checked by test-shell-paths.sh: no sandbox keys.)
      serviceConfig = {
        Type = "oneshot";
        Nice = 19;
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        StateDirectory = stateDir;
      };

      ### Explicit restrictive PATH (hand-picked bin dirs, output-aware):
      ### only these directories exist for the script — nothing inherited
      ### and nothing from the host (/run/current-system is never used).
      ### Unused packages stay out (no sed/awk here).
      environment = {
        AUTO_UPDATE_NOTIFY = if (cfg.notify && hasRealDesktop) then "1" else "0";
        PATH = lib.mkForce (
          lib.concatStringsSep ":" [
            "${config.nix.package}/bin"
            "${config.systemd.package}/bin"
            "${config.system.build.nixos-rebuild}/bin"
            "${pkgs.gitMinimal}/bin"
            "${pkgs.coreutils}/bin"
            "${pkgs.diffutils}/bin"
            "${pkgs.util-linux.bin}/bin"
            "${pkgs.libnotify}/bin"
          ]
        );
      };

      script = ''
        set -euo pipefail
        WORKDIR=/var/lib/${stateDir}
        FLAKE="${cfg.flakeRef}"

        log() { echo "[auto-update] $*"; }
        fail() { log "ERROR: $*"; notify critical "update failed" "$*"; exit 1; }

        ### Best-effort desktop notification: journal is the source of truth.
        ### Sent only with a real DE installed (baked AUTO_UPDATE_NOTIFY) AND
        ### an active graphical session at runtime — never on servers/headless.
        notify() {
          local urgency="$1" title="$2" body="$3"
          log "$title: $body"
          if [[ "$AUTO_UPDATE_NOTIFY" != "1" ]]; then
            return 0
          fi
          local sess stype sactive user uid
          while read -r sess _; do
            [[ -n "$sess" ]] || continue
            stype=$(loginctl show-session "$sess" -p Type --value 2>/dev/null || true)
            sactive=$(loginctl show-session "$sess" -p Active --value 2>/dev/null || true)
            if { [[ "$stype" == "x11" ]] || [[ "$stype" == "wayland" ]]; } && [[ "$sactive" == "yes" ]]; then
              user=$(loginctl show-session "$sess" -p Name --value 2>/dev/null || true)
              [[ -n "$user" && "$user" != "gdm" ]] || continue
              uid=$(id -u "$user" 2>/dev/null || true)
              [[ -n "$uid" ]] || continue
              ### Header branding: --app-name puts "NixOS" in the notification
              ### header instead of "notify-send"; the title is the event itself.
              ### (A header *icon* would need a .desktop entry — none ships the
              ### snowflake, so the -i icon stays with the title. Good enough.)
              runuser -u "$user" -- env \
                DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 \
                XDG_RUNTIME_DIR="/run/user/$uid" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
                notify-send -i "${cfg.notifyIcon}" --app-name="NixOS" -u "$urgency" -t "${toString cfg.notifyTimeout}" "$title" "$body" || true
            fi
          done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
        }

        ### Anti-spam: each generation notifies at most once — re-runs on an
        ### unchanged tree stay journal-only. Failures always notify.
        STATE_FILE="$WORKDIR/notified-generation"
        last_notified=$(cat "$STATE_FILE" 2>/dev/null || true)
        note_once() {
          local sys="$1"; shift
          if [[ "$last_notified" == "$sys" ]]; then
            log "$1: $2 (already notified, silent)"
            return 0
          fi
          notify "$@"
          echo "$sys" > "$STATE_FILE"
        }

        ### Smart state: (source-id, lock-hash) of the last fully successful
        ### run. Identical state → nothing changed upstream: skip update AND
        ### rebuild (no network, no generation spam).
        LAST_OK_FILE="$WORKDIR/last-ok"
        last_ok=$(cat "$LAST_OK_FILE" 2>/dev/null || true)
        SRC_ID=""

        ### Healthcheck inhibit: a failed post-boot validation blocks further
        ### auto-updates until a human clears $WORKDIR/inhibited explicitly.
        if [[ -f "$WORKDIR/inhibited" ]]; then
          log "WARNING: auto-update inhibited ($(head -n1 "$WORKDIR/inhibited"), clear $WORKDIR/inhibited to resume)"
          exit 0
        fi

        ### --- source: local checkout when usable, remote ref otherwise ---
        ${lib.optionalString (cfg.localCheckout != null) ''
          CHECKOUT="${cfg.localCheckout}"
          ### safe.directory: the service runs as root on checkouts owned by
          ### regular users — without it git aborts with "dubious ownership".
          if [[ -d "$CHECKOUT/.git" ]]; then
            if git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" diff --quiet && [[ "$(git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" branch --show-current)" == "${cfg.channel}" ]]; then
              log "pulling local checkout $CHECKOUT"
              if git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" pull --ff-only; then
                FLAKE="$CHECKOUT"
                SRC_ID=$(git -c safe.directory="$CHECKOUT" -C "$CHECKOUT" rev-parse HEAD) || fail "could not read checkout revision"
              else
                log "WARNING: pull failed, falling back to remote ${cfg.flakeRef}"
              fi
            else
              log "WARNING: checkout dirty or not on ${cfg.channel}, using remote ${cfg.flakeRef}"
            fi
          else
            log "no checkout at $CHECKOUT, using remote ${cfg.flakeRef}"
          fi
        ''}

        ### --- remote mode: fresh rev via git, reuse the clone at the  ---
        ### --- same commit, (shallow) re-clone only when it moved. git  ---
        ### --- has no TTL staleness (unlike nix tarball cache), and a     ---
        ### --- shallow clone is small. GIT_URL overridable for tests.    ---
        if [[ "$FLAKE" == "${cfg.flakeRef}" ]]; then
          GIT_URL="''${AUTO_UPDATE_GIT_URL:-https://github.com/${repoSlug}.git}"
          SRC_ID=$(git ls-remote "$GIT_URL" "refs/heads/${cfg.channel}" | cut -f1) || fail "channel resolution failed"
          [[ -n "$SRC_ID" ]] || fail "could not resolve channel revision"
          if [[ -d "$WORKDIR/flake/.git" && "$(git -C "$WORKDIR/flake" rev-parse HEAD 2>/dev/null || true)" == "$SRC_ID" ]]; then
            log "channel still at $SRC_ID, reusing previous clone"
          else
            log "cloning channel @ $SRC_ID"
            rm -rf "$WORKDIR/flake"
            git clone --depth 1 --branch "${cfg.channel}" "$GIT_URL" "$WORKDIR/flake" || fail "flake clone failed"
          fi
          FLAKE="$WORKDIR/flake"
        fi

        LOCK_HASH=$(sha256sum "$FLAKE/flake.lock" | cut -d' ' -f1) || fail "flake.lock missing in $FLAKE"
        if [[ -n "$last_ok" && "$last_ok" == "$SRC_ID $LOCK_HASH" ]]; then
          log "source and inputs unchanged since last successful run, skipping"
          exit 0
        fi

        ${lib.optionalString cfg.updateInputs ''
          log "updating inputs in $FLAKE"
          nix flake update --flake "$FLAKE" || fail "flake update failed"
          LOCK_HASH=$(sha256sum "$FLAKE/flake.lock" | cut -d' ' -f1) || fail "flake.lock missing in $FLAKE after update"
          if [[ -n "$last_ok" && "$last_ok" == "$SRC_ID $LOCK_HASH" ]]; then
            log "inputs already current, skipping rebuild"
            exit 0
          fi
        ''}

        log "rebuilding ${cfg.configuration} (boot, no immediate activation)"
        ### Store-resolved wrapper (system build handle, carries the repo's
        ### flake wrapper): no host dependency, and the explicit --flake
        ### bypasses its auto-injection.
        nixos-rebuild boot \
          --flake "$FLAKE#${cfg.configuration}" \
          --print-build-logs || fail "nixos-rebuild boot failed"
        echo "$SRC_ID $LOCK_HASH" > "$LAST_OK_FILE"

        NEW_SYSTEM=$(readlink -f /nix/var/nix/profiles/system)
        BOOTED_SYSTEM=$(readlink -f /run/booted-system)
        if [[ "$NEW_SYSTEM" == "$BOOTED_SYSTEM" ]]; then
          note_once "$NEW_SYSTEM" normal "already up to date" "running generation is current"
          exit 0
        fi

        NEEDS_REBOOT=0
        for f in kernel init; do
          cmp -s "$BOOTED_SYSTEM/$f" "$NEW_SYSTEM/$f" || NEEDS_REBOOT=1
        done

        if (( NEEDS_REBOOT )); then
          if ${lib.boolToString cfg.allowReboot}; then
            echo "$NEW_SYSTEM" > "$WORKDIR/staged-system"
            notify critical "rebooting" "new kernel/init, automatic reboot"
            systemctl reboot
          else
            echo "$NEW_SYSTEM" > "$WORKDIR/staged-system"
            note_once "$NEW_SYSTEM" normal "reboot required" "new generation staged, reboot to activate"
          fi
        else
          echo "$NEW_SYSTEM" > "$WORKDIR/staged-system"
          note_once "$NEW_SYSTEM" normal "update staged" "new generation will activate on next boot"
        fi
      '';
    };

    systemd.services.nixos-autoupdate-healthcheck = lib.mkIf cfg.healthCheck.enable {
      description = "Validate staged auto-update generation after boot";

      unitConfig = {
        After = lib.optional cfg.healthCheck.requireNetwork "network-online.target";
        Wants = lib.optional cfg.healthCheck.requireNetwork "network-online.target";
      };

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = cfg.healthCheck.timeout + 60;
        StateDirectory = stateDir;
      };

      ### Explicit restrictive PATH (hand-picked bin dirs, output-aware).
      environment = {
        AUTO_UPDATE_NOTIFY = if (cfg.notify && hasRealDesktop) then "1" else "0";
        PATH = lib.mkForce (
          lib.concatStringsSep ":" [
            "${config.systemd.package}/bin"
            "${pkgs.coreutils}/bin"
            "${pkgs.gnugrep}/bin"
            "${pkgs.util-linux.bin}/bin"
            "${pkgs.libnotify}/bin"
          ]
        );
      };

      script = ''
        set -euo pipefail
        WORKDIR=/var/lib/${stateDir}
        STAGED_FILE="$WORKDIR/staged-system"
        INHIBITED_FILE="$WORKDIR/inhibited"

        log() { echo "[auto-update-healthcheck] $*"; }

        ### Duplicated from nixos-auto-update (kept inline so test
        ### harnesses extract each service verbatim).
        notify() {
          local urgency="$1" title="$2" body="$3"
          log "$title: $body"
          if [[ "$AUTO_UPDATE_NOTIFY" != "1" ]]; then
            return 0
          fi
          local sess stype sactive user uid
          while read -r sess _; do
            [[ -n "$sess" ]] || continue
            stype=$(loginctl show-session "$sess" -p Type --value 2>/dev/null || true)
            sactive=$(loginctl show-session "$sess" -p Active --value 2>/dev/null || true)
            if { [[ "$stype" == "x11" ]] || [[ "$stype" == "wayland" ]]; } && [[ "$sactive" == "yes" ]]; then
              user=$(loginctl show-session "$sess" -p Name --value 2>/dev/null || true)
              [[ -n "$user" && "$user" != "gdm" ]] || continue
              uid=$(id -u "$user" 2>/dev/null || true)
              [[ -n "$uid" ]] || continue
              runuser -u "$user" -- env \
                DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 \
                XDG_RUNTIME_DIR="/run/user/$uid" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
                notify-send -i "${cfg.notifyIcon}" --app-name="NixOS" -u "$urgency" -t "${toString cfg.notifyTimeout}" "$title" "$body" || true
            fi
          done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
        }

        check_health() {
          local u bad=0 route_ok=0 iface dest gw
          for u in ${lib.escapeShellArgs cfg.healthCheck.units}; do
            systemctl is-active --quiet "$u" || { log "unhealthy unit: $u"; bad=1; }
          done
          if ${lib.boolToString cfg.healthCheck.requireNetwork}; then
            ### Default route via a gateway (lo excluded: destination 00000000
            ### with a 00000000 gateway is just loopback, not uplink).
            while read -r iface dest gw _; do
              if [[ "$iface" != "lo" && "$dest" == "00000000" && "$gw" != "00000000" ]]; then
                route_ok=1
                break
              fi
            done < "''${PROC_NET_ROUTE:-/proc/net/route}" 2>/dev/null || true
            if (( ! route_ok )); then
              log "no default IPv4 route"
              bad=1
            fi
          fi
          ### Essential-boot signal: any failed unit fails validation.
          ### (Fail-open on tool error: systemctl itself failing will usually
          ### trip the unit checks above anyway.)
          if ${lib.boolToString cfg.healthCheck.checkFailedUnits}; then
            if systemctl list-units --state=failed --no-legend --no-pager 2>/dev/null | grep -q .; then
              log "failed units present"
              bad=1
            fi
          fi
          return $bad
        }

        BOOTED=$(readlink -f /run/booted-system)
        if [[ ! -f "$STAGED_FILE" ]]; then
          log "no staged generation, nothing to validate"
          exit 0
        fi
        STAGED=$(cat "$STAGED_FILE")
        if [[ "$STAGED" != "$BOOTED" ]]; then
          log "booted $BOOTED is not the staged $STAGED, nothing to validate"
          exit 0
        fi

        log "validating staged generation $STAGED"
        if ! check_health; then
          {
            echo "auto-update inhibited: unhealthy staged boot"
            echo "date: $(date -u +%FT%TZ)"
            echo "booted: $BOOTED"
          } > "$INHIBITED_FILE"
          notify critical "post-boot healthcheck failed" "auto-update inhibited (clear $INHIBITED_FILE to resume)"
          exit 1
        fi
        rm -f "$STAGED_FILE" "$INHIBITED_FILE"
        log "staged generation healthy, adopted"
      '';
    };

    systemd.timers.nixos-auto-update = {
      description = "Timer for automatic system updates";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.startDelay;
        OnUnitInactiveSec = cfg.checkInterval;
        RandomizedDelaySec = cfg.randomizedDelay;
        Persistent = true;
        Unit = "nixos-auto-update.service";
      };
    };
  };
}
