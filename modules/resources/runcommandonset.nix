{ config, lib, ... }:
with lib;
let
  cfg = config.dsc;
in
{
  options.dsc.runCommands = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        executable = mkOption {
          type = types.str;
          description = "The executable to run on set.";
        };
        arguments = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Arguments to pass to the executable.";
        };
        exitCode = mkOption {
          type = types.ints.unsigned;
          default = 0;
          description = "Expected exit code to indicate success.";
        };
        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [];
        };
      };
    }));
    default = {};
    description = "Commands to execute during DSC set operation (Microsoft.DSC.Transitional/RunCommandOnSet).";
  };

  config.dsc.resources = mkMerge (
    mapAttrsToList (name: cmd: {
      "${name}" = {
        type = "Microsoft.DSC.Transitional/RunCommandOnSet";
        properties = {
          executable = cmd.executable;
        } // optionalAttrs (cmd.arguments != []) {
          arguments = cmd.arguments;
        } // optionalAttrs (cmd.exitCode != 0) {
          exitCode = cmd.exitCode;
        };
        dependsOn = cmd.dependsOn;
      };
    }) cfg.runCommands
  );
}
