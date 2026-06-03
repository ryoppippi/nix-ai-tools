{
  pkgs,
  perSystem,
  ...
}:
let
  dolt = perSystem.self.dolt;
  beads = pkgs.callPackage ../beads/package.nix {
    inherit dolt;
    inherit (perSystem.self) go-bin;
  };
in
pkgs.callPackage ./package.nix {
  inherit beads dolt;
  inherit (perSystem.self) go-bin;
}
