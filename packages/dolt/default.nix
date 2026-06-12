# nixpkgs ships dolt 1.x, but gascity's managed bd/Dolt runtime requires
# Dolt >= 2.1.0. Bump the nixpkgs package; dolt 2.1.2 requires go >= 1.26.2,
# newer than nixpkgs' default Go, so build with go-bin.
{ pkgs, perSystem, ... }:
let
  base = pkgs.dolt.override {
    buildGoModule = pkgs.buildGoModule.override { go = perSystem.self.go-bin; };
  };
in
(base.overrideAttrs (old: rec {
  version = "2.1.7";
  src = pkgs.fetchFromGitHub {
    owner = "dolthub";
    repo = "dolt";
    rev = "v${version}";
    hash = "sha256-ZMK0XiVaSZObr23mQ3OKA5t8wDV8l8SN2Rhh3VjJo1w=";
  };
  vendorHash = "sha256-l0SHq3WTajqGTE5sV6RgLgVLS+i7AhAxfJkJmAvv2ok=";
  passthru = (old.passthru or { }) // {
    hideFromDocs = true;
    updateEvenIfHidden = true;
  };
}))
