{ config, ... }:

{
 ### Enable swap devices when this expression is imported
 swapDevices = [{
   device = "/var/lib/swapfile";
   size = 8*1024;
 }];
}
