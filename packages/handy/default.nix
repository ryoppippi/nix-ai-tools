{ pkgs, perSystem, ... }:
pkgs.callPackage ./package.nix {
  autoPatchelfHook = perSystem.self.formatelf;
}
