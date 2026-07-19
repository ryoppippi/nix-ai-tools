{
  pkgs,
  packages,
  ...
}:
let
  # Filter to visible, runnable packages
  visibleNames = builtins.filter (
    name: name != "default" && !(packages.${name}.passthru.hideFromDocs or false)
  ) (builtins.attrNames packages);

  # Build "name\tdescription" lines
  packageLines = map (name: "${name}\t${packages.${name}.meta.description or ""}") visibleNames;

  packageList = builtins.concatStringsSep "\n" packageLines;
in
pkgs.callPackage ./package.nix { inherit packageList; }
