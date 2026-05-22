{ config, lib, ... }:
with lib;
{
  dsc = {
    configurationName = "WebServer";

    windowsFeatures = {
      "Web-Server" = {
        ensure = "Present";
      };
    };

    files = {
      indexHtml = {
        ensure = "Present";
        sourcePath = "C:\\Source\\index.html";
        destinationPath = "C:\\inetpub\\wwwroot\\index.html";
        dependsOn = [ "Web-Server" ];
      };
    };

    services = {
      W3SVC = {
        ensure = "Present";
        state = "Running";
        dependsOn = [ "Web-Server" ];
      };
    };
  };
}
