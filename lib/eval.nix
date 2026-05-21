{ pkgs, lib, modules }:
let
  coreModule = ../modules/core.nix;

  result = lib.evalModules {
    modules = [ coreModule ] ++ modules;
  };

  sanitize = x:
    if lib.isAttrs x then
      lib.filterAttrs (n: v: v != null && n != "_module" && n != "_args")
        (lib.mapAttrs (n: v: sanitize v) x)
    else if lib.isList x then
      map sanitize x
    else
      x;

  config = sanitize result.config;

  emit = import ./emit.nix { inherit lib config; };
in
pkgs.writeText "dsc-configuration.ps1" emit
