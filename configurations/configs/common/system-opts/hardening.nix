{
  lib,
  config,
  pkgs,
  ...
}:

let
  ### Declare unused module and block them automatically and dynamically with blacklistedKernelModules and extraModprobeConfig options
  unusedNetModules = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "n-hdlc"
    "ax25"
    "netrom"
    "x25"
    "rose"
    "decnet"
    "econet"
    "af_802154"
    "ipx"
    "appletalk"
    "psnap"
    "p8023"
    "p8022"
    "can"
    "atm"
  ];
  unusedAdvModules = [
    "firewire-core"
    "thunderbolt"
  ];
  unusedFilesystemModules = [
    "cramfs"
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
  ];

  unusedAllModulesCategories = unusedNetModules ++ unusedAdvModules ++ unusedFilesystemModules;
in
{
  boot = {
    blacklistedKernelModules = unusedAllModulesCategories;

    ### Concat list into string named "install (modules name) /bin/true", "m:" take unusedAllModulesCategories as a value
    extraModprobeConfig = lib.mkIf (unusedAllModulesCategories != [ ]) ''
      ${lib.concatStringsSep "\n" (
        map (m: "install ${m} ${pkgs.coreutils}/bin/true") unusedAllModulesCategories
      )}
    '';
    kernelParams = [
      "quiet"

      ### Hardening
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "pti=on"
      "vsyscall=none"
      "debugfs=off"
      "module.sig_enforce=1"
      "random.trust_cpu=off"
    ]
    ++ (
      if (config.hardware.cpu.intel.updateMicrocode && config.virtualisation.libvirtd.enable) then
        [
          "intel_iommu=on"
          "iommu=pt"
        ]
      else if (config.hardware.cpu.amd.updateMicrocode && config.virtualisation.libvirtd.enable) then
        [
          "amd_iommu=on"
          "iommu=pt"
        ]
      else
        [
          "init_on_alloc=1"
          "init_on_free=1"
        ]
    );
    # initrd.blacklistedKernelModules = unusedAllModulesCategories;
    kernel.sysctl = {
      "kernel.panic" = 10;
      "vm.swappiness" = 10;

      # Disable Coredump
      "kernel.core_pattern" = lib.mkForce "|${pkgs.coreutils-full}/bin/false";

      # Hardening (kernel)
      "kernel.printk" = "3 3 3 3";
      "kernel.kptr_restrict" = 2;
      "kernel.kexec_load_disabled" = 1;
      "kernel.perf_event_paranoid" = 3;
      "kernel.dmesg_restrict" = 1;
      "kernel.unprivileged_bpf_disabled" = 1;
      "kernel.yama.ptrace_scope" = 1;
      "fs.suid_dumpable" = 0; # For coredump too

      # Hardening (filesystem)
      "fs.protected_symlinks" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;

      # Hardening (memory)
      "vm.mmap_rnd_bits" = 32;
      "vm.mmap_rnd_compat_bits" = 16;
      "vm.unprivileged_userfaultfd" = 0;

      # Hardening (network)
      "net.core.bpf_jit_enable" = 1;
      "net.core.bpf_jit_harden" = 2;
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_rfc1337" = 1;

      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;

      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;

      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;

      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
    };
  };

  ### Declare machine-id
  environment.etc."machine-id" = {
    text = "b08dfa6083e7567a1921a715000001fb";
    mode = "0444";
  };

  ### Mount /mnt as a tmpfs (limit persistant folder)
  fileSystems."/mnt" = {
    fsType = "tmpfs";
    options = [
      "nodev"
      "noexec"
      "nosuid"
      "noswap"
      "mode=755"
      "size=4k"
    ];
  };

  ### Disable systemd-coredump (https://www.linuxtricks.fr/wiki/desactiver-les-core-dumps-sous-linux-systemd-coredump-inclus)
  systemd.coredump.settings.Coredump = {
    Storage = "none";
  };
}
