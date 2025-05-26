{ lib, config, ... }:

{
 ### intel firmware
 hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
