{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Install specific package for AI tools (for desktop and CLI)
  environment.systemPackages =
    with pkgs.pkgsUnstable;
    [
      opencode
      mcp-nixos
      nixd # Nix lsd server
    ]
    ++ (lib.optionals config.services.xserver.enable (with pkgs.pkgsPr; [ claude-desktop ]));
}
