{ pkgs }:
let
  # ctranslate2 4.8.1 ships a non-reproducing fetchSubmodules hash; scope the
  # fix to this package via pkgs.extend. See the overlay for details.
  pkgs' = pkgs.extend (import ../../overlays/ctranslate2-hash-fix.nix);
in
pkgs'.callPackage ./package.nix { }
