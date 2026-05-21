{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.powerShellScripts = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        getScript = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "PowerShell script to run for get operation.";
        };
        setScript = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "PowerShell script to run for set operation.";
        };
        testScript = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "PowerShell script to run for test operation.";
        };
        input = mkOption {
          type = types.nullOr types.anything;
          default = null;
          description = "Optional input data passed to the scripts.";
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
        };
      };
    }));
    default = {};
    description = "Inline PowerShell 7 scripts (Microsoft.DSC.Transitional/PowerShellScript).";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: script: {
      "${name}" = {
        type = "Microsoft.DSC.Transitional/PowerShellScript";
        properties = {
        } // optionalAttrs (script.getScript != null) {
          getScript = script.getScript;
        } // optionalAttrs (script.setScript != null) {
          setScript = script.setScript;
        } // optionalAttrs (script.testScript != null) {
          testScript = script.testScript;
        } // optionalAttrs (script.input != null) {
          input = script.input;
        };
        dependsOn = script.dependsOn;
      };
    }) cfg.powerShellScripts
  );
}
