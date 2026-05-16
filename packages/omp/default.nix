{
  pkgs,
  flake,
  perSystem,
  ...
}:
let
  bun2nix = (pkgs.extend flake.inputs.bun2nix.overlays.default).bun2nix;
in
pkgs.callPackage ./package.nix {
  inherit bun2nix;
  bun = perSystem.self.bun-bin;
}
