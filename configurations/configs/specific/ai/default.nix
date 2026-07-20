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
      nixd

      ### LSP servers (also used by opencode)
      bash-language-server
      gopls
      lua-language-server
      marksman
      nil
      pyright
      rust-analyzer
      typescript-language-server
      yaml-language-server
    ]
    ++ (lib.optionals config.services.xserver.enable (with pkgs.pkgsPr; [ claude-desktop ]));
}
