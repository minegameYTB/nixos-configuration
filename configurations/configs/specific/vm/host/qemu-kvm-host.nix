{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Virt-manager
  programs.virt-manager.enable = true;

  ### Vm specific package
  environment.systemPackages = with pkgs; [ libguestfs ];

  ### KSM ram optimisation
  hardware.ksm.enable = true;

  ### Specific kernel configuration
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1 report_ignored_msrs=0
  '';

  ### Virtualisation settings
  virtualisation = {
    kvmgt.enable = true;
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;

      shutdownTimeout = 90;
      onShutdown = "shutdown";
      onBoot = "ignore";
      qemu = {
        ### Define package for vm
        package = pkgs.qemu_kvm;

        ### Tpm support in qemu
        swtpm.enable = true;

        ### Run qemu vm in qemu-libvirtd user instead of root
        runAsRoot = false;
      };
    };
  };

  ### Temporary systemd service (delete later)
  #systemd.services."qemu-libvirtd-chmod" = {
  #  enable = config.virtualisation.libvirtd.qemu.runAsRoot != true;
  # description = "Define 'qemu-libvirtd' user as a new owner of '/var/lib/libvirt/qemu/*' directory";
  # wantedBy = [ "multi-user.target" ];

  ### Strictly use coreutils package for this service (+ all hardening used) (differant of systemd.services.<name>.path, this option add to path instead of overwrite the path)
  # environment.PATH = lib.mkForce "${pkgs.coreutils}/bin";
  # serviceConfig = {
  #   Type = "oneshot";

  ### Run service as root (for chmod)
  #   User = "root";

  ### Hardening service (to only touch /var/lib/libvirt/qemu/* dir)
  #   ProtectSystem = "strict";
  #   ProtectHome = "read-only";
  #   PrivateTmp = "true";
  #  NoNewPrivileges = "yes";
  # };
  #  script = ''
  ### see description of "virtualisation.libvirtd.qemu.runAsRoot" for more info
  #   targetDir="/var/lib/libvirt/qemu"
  #   newUser="qemu-libvirtd"
  #   currentUser=$(stat -c "%U" "$targetDir")

  ### test if root is the owner of targetDir
  #   if [ "$currentOwner" = "$newUser" ]; then
  #     exit 0
  #   fi

  ### apply new owner if it's root (folder)
  #   chown -R $newUser:$newUser $targetDir

  ### apply new owner on all directory of this directory
  #   chown -R $newUser $targetDir/*
  # '';
  #};

  ### Nix specific
  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = {
      memorySize = 1024; # Use 1024MiB memory.
      cores = 2;
      graphics = true; # Boot the vm in a window.
      diskSize = 15000; # Virtual machine disk size in MB.
    };
  };
}
