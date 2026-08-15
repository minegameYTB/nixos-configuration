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
  environment.systemPackages = with pkgs; [
    libguestfs
    nur.repos.minegameYTB.kvm-archive
  ];

  ### KSM ram optimisation
  #hardware.ksm.enable = true;

  ### Virtualisation settings
  virtualisation = {
    #kvmgt.enable = true;
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      #package = pkgs.libvirt.override {
      #  enableXen = false;
      #  enableZfs = false;
      #};
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

  ### Nix specific
  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = {
      memorySize = 4096; # Use 4096MiB memory.
      cores = 2;
      graphics = true; # Boot the vm in a window.
      diskSize = 15000; # Virtual machine disk size in MB.

      # virgl GPU acceleration (requires OpenGL host session, e.g. X11/Wayland)
      qemu.options = [
        "-device virtio-vga-gl"
        "-display gtk,gl=on"
      ];
    };
  };
}
