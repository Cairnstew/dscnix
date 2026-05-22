{ config, lib, ... }:
with lib;
{
  dsc = {
    configurationName = "WindowsWorkstation";

    # Windows Optional Features (native DSC v3)
    optionalFeatures = {
      "Microsoft-Windows-Subsystem-Linux" = {
        state = "Installed";
      };
      "VirtualMachinePlatform" = {
        state = "Installed";
      };
    };

    # Windows Registry settings
    registry = {
      "DisableCortana" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search";
        valueName = "AllowCortana";
        valueData = { DWord = 0; };
      };
      "DarkMode" = {
        keyPath = "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
        valueName = "AppsUseLightTheme";
        valueData = { DWord = 0; };
      };
    };

    # Native Windows services (DSC v3)
    windowsServices = {
      "Audiosrv" = {
        status = "Running";
        startType = "Automatic";
      };
    };

    # Firewall rules
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

    # Run a command on set
    runCommands = {
      "RefreshEnv" = {
        executable = "cmd.exe";
        arguments = [ "/c" "setx" "FOO" "bar" ];
      };
    };

    # OS assertion
    osInfo = {
      "AssertWindows" = {
        family = "Windows";
      };
    };

    # Legacy PSDscResources (wrapped in Microsoft.Windows/WindowsPowerShell adapter)
    windowsFeatures = {
      "Telnet-Client" = {
        ensure = "Absent";
      };
    };

    files = {
      readme = {
        ensure = "Present";
        sourcePath = "C:\\Source\\readme.txt";
        destinationPath = "C:\\inetpub\\wwwroot\\readme.txt";
      };
    };
  };
}
