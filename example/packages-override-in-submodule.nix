{ inputs, config, pkgs, ... }:

{
 ### In this example, environmnent.systemPackages is used to add nmon as a global package, pkgs.<package name>.overrideAttrs allows to modify some information of the "nmon" expression, in this example, this modification change the program name (here, pname variable) to nmon-custom, the version (2025-unstable) and add pversion variable
 
 ### it can be used recursively by using the “rec” argument next to the “oldAttrs” function (defined as a “marker” to refer to the base expression).
 environment.systemPackages = with pkgs; [
   (pkgs.nmon.overrideAttrs (oldAttrs: rec {
     pname = "nmon-custom";
     version = "2025-unstable";
     pversion = oldAttrs.version;
     
     src = fetchurl {
       url = "mirror://sourceforge/nmon/lmon${pversion}.c";
       sha256 = "sha256-D40qpgR93fRoD0JwtH+afqAAiETRktX/WUDivO+Ppac=";
     };
   }))
 ]
}
