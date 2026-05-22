{ config, lib, ... }:
with lib;
{
  dsc = {
    configurationName = "NativeWindowsConfig";

    # Native DSC v3 resources only
    registry = {
      "DarkMode" = {
        keyPath = "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
        valueName = "AppsUseLightTheme";
        valueData = { DWord = 0; };
      };
    };

    windowsServices = {
      "Audiosrv" = {
        status = "Running";
        startType = "Automatic";
      };
    };

    optionalFeatures = {
      "Microsoft-Windows-Subsystem-Linux" = {
        state = "Installed";
      };
    };

    firewallRules = {
      "AllowRDP" = {
        direction = "Inbound";
        action = "Allow";
        protocol = 6;
        localPorts = "3389";
        enabled = true;
        profiles = [ "Domain" "Private" ];
      };
    };
  };
}
