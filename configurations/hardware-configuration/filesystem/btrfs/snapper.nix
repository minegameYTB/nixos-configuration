{
  config,
  lib,
  pkgs,
  ...
}:

let
  ### Sanoid-style snapshots with period-tagged descriptions. Each cadence
  ### (hourly/daily/weekly/monthly) creates its own snapshot tagged with
  ### userdata period=<name> and prunes independently (like sanoid's
  ### autosnap_hourly_/autosnap_daily_/... snapshots).
  periodicScript =
    period: keep:
    pkgs.writeShellScript "snapper-${period}-home" ''
      set -euo pipefail

      CONFIG="home"
      PERIOD="${period}"
      KEEP="${toString keep}"
      SNAPPER="${pkgs.snapper}/bin/snapper"

      "$SNAPPER" -c "$CONFIG" create --description "$PERIOD" --userdata "period=$PERIOD"

      ids=$("$SNAPPER" --no-headers --csvout -c "$CONFIG" list --columns number,userdata \
        | awk -F',' -v tag="period=$PERIOD" '$2 == tag {print $1}')
      total=$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l)

      if [ "$total" -gt "$KEEP" ]; then
        del=$(printf '%s\n' "$ids" | head -n "$(( total - KEEP ))" | tr '\n' ' ')
        "$SNAPPER" -c "$CONFIG" delete --sync $del
      fi
    '';

  periods = [
    {
      name = "snapper-hourly";
      period = "hourly";
      keep = 24;
      OnCalendar = "hourly";
      description = "Hourly snapper snapshot (home)";
    }
    {
      name = "snapper-daily";
      period = "daily";
      keep = 15;
      OnCalendar = "daily";
      description = "Daily snapper snapshot (home)";
    }
    {
      name = "snapper-weekly";
      period = "weekly";
      keep = 4;
      OnCalendar = "weekly";
      description = "Weekly snapper snapshot (home)";
    }
    {
      name = "snapper-monthly";
      period = "monthly";
      keep = 3;
      OnCalendar = "monthly";
      description = "Monthly snapper snapshot (home)";
    }
  ];
in
lib.mkIf (config.fileSystems."/".fsType == "btrfs") {
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    FSTYPE = "btrfs";
    ALLOW_USERS = [ "minegame" ];
    ### Timeline built-in disabled — custom period timers below manage
    ### creation + pruning (number/timeline cleanup left inert).
    TIMELINE_CREATE = false;
    TIMELINE_CLEANUP = false;
  };

  systemd.services = lib.mkMerge (
    (map (
      p: {
        ${p.name} = {
          inherit (p) description;
          after = [ "snapperd.service" ];
          wants = [ "snapperd.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = [ (periodicScript p.period p.keep) ];
          };
        };
      }
    ) periods)
    ++ [
      ### Disable the built-in snapper-timeline/-cleanup services (replaced
      ### by the custom period timers above).
      {
        snapper-timeline.enable = lib.mkForce false;
        snapper-cleanup.enable = lib.mkForce false;
      }
    ]
  );

  systemd.timers = lib.mkMerge (
    (map (
      p: {
        ${p.name} = {
          inherit (p) description;
          wantedBy = [ "timers.target" ];
          timerConfig = {
            inherit (p) OnCalendar;
            Persistent = true; # catch up on missed runs after shutdown (like sanoid)
          };
        };
      }
    ) periods)
    ++ [
      {
        snapper-timeline.enable = lib.mkForce false;
        snapper-cleanup.enable = lib.mkForce false;
      }
    ]
  );
}