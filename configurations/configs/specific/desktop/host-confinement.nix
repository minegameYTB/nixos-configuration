{
  lib,
  config,
  ...
}:

{
  ### Mount/sandbox confinement for host SYSTEM units (desktop scope).
  ### Counterpart of gnome-confinement.nix (user units only).
  ### Each block is gated on its own hardware/service switch — no CLI impact.
  ###
  ### Tier A only for now: directives with zero functional risk. Tier B
  ### (ProtectSystem=strict + ReadWritePaths) waits for a real-hardware
  ### pairing test — bluetoothd persists pairing keys in /var/lib/bluetooth,
  ### strict without exception would lose pairings on reboot.
  ###
  ### Note: upstream nixpkgs (services/hardware/bluetooth.nix) already confines
  ### bluetoothd harder than the reference project ever did — NoNewPrivileges,
  ### RestrictNamespaces, MemoryDenyWriteExecute, RestrictSUIDSGID,
  ### SystemCallFilter=@system-service (whitelist), LockPersonality,
  ### RestrictRealtime, ProtectProc, PrivateTmp, arch native — and deliberately
  ### leaves ProtectKernelModules/Tunables=false (hardware module loading) and
  ### PrivateNetwork=false (tethering). Do NOT re-set those keys here
  ### (merge conflict + would break hardware init). This block only adds what
  ### upstream lacks. Upstream also sets restartIfChanged=false (restarting
  ### bluetoothd drops mice/keyboards) — keep that in mind on switch.
  systemd.services = {
    ### bluetoothd delta on top of upstream: hide /home+/root+/run/user
    ### (needs none of them), block kernel log reads, privatize UTS.
    ### Source idea: ~/Projets/github/nix-system-services-hardened/services/
    ### bluetooth.nix — but upstream already covers its whole set and more,
    ### so only the 3 missing zero-risk keys are applied here.
    bluetooth = lib.mkIf config.hardware.bluetooth.enable {
      serviceConfig = {
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectHostname = true;
      };
    };
  };
}
