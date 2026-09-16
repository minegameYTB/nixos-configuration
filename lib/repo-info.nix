# lib/repo-info.nix — pure Nix (builtins only, no nixpkgs dependency).
#
# Turns a git remote URL + channel into everything location-aware code
# needs, whatever the forge: GitHub and GitLab get their native flake
# schemes, everything else (Codeberg, self-hosted, SSH remotes) falls back
# to generic git+https / git+ssh flake refs. lib/repo.nix stays the single
# source of truth for the URL itself.
#
# Usage:
#   import ./repo-info.nix { url = "https://github.com/o/r"; channel = "c"; }
#   → { host, slug, gitUrl, flakeRef }
{ url, channel }:

let
  ### Strip one trailing suffix (order matters: "/" first, then ".git").
  stripSuffix = suffix: s:
    let
      len = builtins.stringLength s;
      slen = builtins.stringLength suffix;
    in
    if slen <= len && builtins.substring (len - slen) slen s == suffix then
      builtins.substring 0 (len - slen) s
    else
      s;
  clean = stripSuffix ".git" (stripSuffix "/" url);

  ### builtins.match is full-match anchored; specific forges first.
  gh = builtins.match "https?://github\\.com/([^/]+/[^/]+)" clean;
  gl = builtins.match "https?://gitlab\\.com/(.+)" clean;
  ssh = builtins.match "git@([^:]+):(.+)" clean;
  https = builtins.match "https?://([^/]+)/(.+)" clean;

  info =
    if gh != null then {
      host = "github";
      slug = builtins.head gh;
    } else if gl != null then {
      host = "gitlab";
      slug = builtins.head gl;
    } else if ssh != null then {
      host = "ssh";
      sshHost = builtins.head ssh;
      slug = builtins.elemAt ssh 1;
    } else if https != null then {
      host = "https";
      httpsHost = builtins.head https;
      slug = builtins.elemAt https 1;
    } else
      throw "repo-info: unsupported git remote URL '${url}' (expected https://host/owner/repo or git@host:owner/repo)";
in
{
  inherit (info) host slug;
  gitUrl =
    if info.host == "ssh" then
      "git@${info.sshHost}:${info.slug}.git"
    else if info.host == "https" then
      "https://${info.httpsHost}/${info.slug}.git"
    else if info.host == "gitlab" then
      "https://gitlab.com/${info.slug}.git"
    else
      "https://github.com/${info.slug}.git";
  flakeRef =
    if info.host == "github" then
      "github:${info.slug}?ref=${channel}"
    else if info.host == "gitlab" then
      "gitlab:${info.slug}?ref=${channel}"
    else if info.host == "ssh" then
      "git+ssh://git@${info.sshHost}/${info.slug}.git?ref=${channel}"
    else
      "git+https://${info.httpsHost}/${info.slug}.git?ref=${channel}";
}
