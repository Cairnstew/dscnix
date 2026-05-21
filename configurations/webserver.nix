{ config, lib, ... }:
with lib;
{
  dsc = {
    configurationName = "WebServer";
    nodes = [ "web-01" "web-02" ];
    imports = [ "PSDscResources" ];

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
        dependsOn = [ "indexHtml" ];
      };
    };
  };
}
