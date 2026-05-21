{ lib, ... }:
with lib;
{
  imports = [
    ./resources/windowsfeature.nix
    ./resources/file.nix
    ./resources/service.nix
    ./resources/registry.nix
    ./resources/windowsService.nix
    ./resources/firewall.nix
    ./resources/optionalFeatures.nix
    ./resources/featuresOnDemand.nix
    ./resources/runcommandonset.nix
    ./resources/powershellScript.nix
    ./resources/windowsPowerShellScript.nix
    ./resources/osinfo.nix
    ./resources/rebootpending.nix
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
