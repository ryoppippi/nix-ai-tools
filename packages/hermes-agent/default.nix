{
  pkgs,
  perSystem,
  flake,
  ...
}:
let
  # ctranslate2 4.7.x tests invoke test_torch_variables, which calls into
  # cpuinfo at import time. On the aarch64-linux remote builders the sandbox
  # does not expose a readable /proc/cpuinfo, so every parametrisation of
  # that test dies with "RuntimeError: Failed to initialize cpuinfo!".
  # The library itself works fine at runtime; only the test fixture is hostile
  # to the build environment. Skip the offending test on aarch64-linux until
  # nixpkgs grows the same workaround.
  # ctranslate2 4.8.1 ships a non-reproducing fetchSubmodules hash; scope the
  # fix to this package via pkgs.extend. See the overlay for details.
  pkgs' = pkgs.extend (import ../../overlays/ctranslate2-hash-fix.nix);
  python3 = pkgs'.python3.override {
    packageOverrides = _final: prev: {
      ctranslate2 = prev.ctranslate2.overridePythonAttrs (old: {
        disabledTests =
          (old.disabledTests or [ ])
          ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isAarch64 [
            "test_torch_variables"
          ];
      });
    };
  };
in
pkgs.callPackage ./package.nix {
  inherit flake python3;
  inherit (perSystem.self) versionCheckHomeHook;
}
