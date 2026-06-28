{
  pkgs,
  ...
}@args:
pkgs.callPackage ./package.nix (
  {
    mkRustyV8Archive = pkgs.callPackage ../../lib/rusty-v8.nix { };
  }
  # Avoid callPackage autofilling `src` from the throwing `pkgs.src` alias.
  // {
    src = null;
  }
  // builtins.removeAttrs args [ "pkgs" ]
)
