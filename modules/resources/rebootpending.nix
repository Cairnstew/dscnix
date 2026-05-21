{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.rebootPending = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        # No configurable properties; this is a read-only assertion resource.
      };
    }));
    default = {};
    description = "Check for pending reboot (Microsoft.Windows/RebootPending). Read-only assertion resource.";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: _: {
      "${name}" = {
        type = "Microsoft.Windows/RebootPending";
        properties = {};
      };
    }) cfg.rebootPending
  );
}
