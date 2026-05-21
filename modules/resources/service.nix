{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.services = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        ensure = mkOption {
          type = types.enum [ "Present" "Absent" ];
          default = "Present";
        };
        state = mkOption {
          type = types.enum [ "Running" "Stopped" ];
          default = "Running";
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
        };
      };
    }));
    default = {};
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: service: {
      "${name}" = {
        type = "Service";
        properties = {
          Name = name;
          Ensure = service.ensure;
          State = service.state;
        };
        dependsOn = service.dependsOn;
      };
    }) cfg.services
  );
}
