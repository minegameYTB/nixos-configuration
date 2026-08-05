{
  lib,
  config,
  pkgs,
  ...
}:

lib.mkIf pkgs.stdenvNoCC.hostPlatform.isx86_64 {
  ### Intel GPU firmware (GuC, HuC, DMC)
  hardware.enableRedistributableFirmware = true;

  ### Intel i915 kernel module (early load)
  boot.kernelModules = [ "i915" ];

  ### Enable GuC/HuC firmware loading for better performance and video features
  boot.kernelParams = [
    "i915.enable_guc=2"
    "i915.enable_fbc=1"
  ];

  ### Graphics stack - Intel GPU drivers and acceleration
  hardware.graphics = {
    extraPackages = with pkgs; [
      ### VA-API
      intel-media-driver
      intel-vaapi-driver
      libva
      libva-vdpau-driver
      libvdpau-va-gl
      vdpauinfo

      ### Vulkan (ANV driver is in mesa, loader is separate)
      vulkan-loader
      vulkan-tools
      vulkan-validation-layers

      ### OpenCL / oneAPI
      intel-compute-runtime
      ocl-icd

      ### GPU tools
      intel-gpu-tools
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      ### VA-API 32-bit (for Wine / 32-bit apps)
      intel-media-driver
      intel-vaapi-driver
      libva
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };
}
