{ lib, ... }:
with lib;
{
  imports = [
    ./resources/windowsfeature.nix
    ./resources/file.nix
    ./resources/service.nix
  ];

  options.dsc = {
    configurationName = mkOption {
      type = types.str;
      description = "Name of the DSC configuration.";
    };

    nodes = mkOption {
      type = types.listOf types.str;
      default = [ "localhost" ];
      description = "Target nodes for the DSC configuration.";
    };

    imports = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "DSC resource modules to import.";
    };

    resources = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          type = mkOption {
            type = types.str;
            description = "DSC resource type.";
          };

          properties = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            description = "Resource properties.";
          };

          dependsOn = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Dependencies on other resources.";
          };
        };
      });
      default = {};
      description = "DSC resources to configure.";
    };
  };
}
