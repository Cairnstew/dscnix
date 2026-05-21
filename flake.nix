{
  description = "dscnix — Generate PowerShell DSC configurations from NixOS modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = nixpkgs.lib;
    in
    {
      lib = {
        evalDscConfiguration = modules:
          import ./lib/eval.nix { inherit pkgs lib modules; };
      };

      packages.x86_64-linux.example =
        self.lib.evalDscConfiguration [ ./configurations/webserver.nix ];
    };
}
