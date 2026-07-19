{
  description = "Exploring integration between Nix and AI coding agents";
  nixConfig = {
    allow-import-from-derivation = false;
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachSystem = lib.genAttrs systems;

      # The flake itself, as passed to packages/checks (`flake.lib`,
      # `flake.inputs`, source path via string interpolation).
      flake = self // {
        inherit inputs;
      };

      # Call a function with only the arguments it declares.
      callWith = args: fn: fn (builtins.intersectAttrs (builtins.functionArgs fn) args);

      packageNames = builtins.attrNames (
        lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./packages)
      );

      checkNames = lib.mapAttrsToList (name: _type: lib.removeSuffix ".nix" name) (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
          builtins.readDir ./checks
        )
      );

      pkgsFor = eachSystem (system: import nixpkgs { inherit system; });

      # Every package under packages/, built against the given package set.
      #
      # A package with only a package.nix is called from a scope containing
      # all in-repo packages plus shared helpers, so dependencies like
      # `wrapBuddy` or `platformSource` resolve by argument name. A package
      # with a default.nix is called with { pkgs, packages, flake, inputs,
      # system }.
      mkPackagesFor =
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;

          scope = lib.makeScope pkgs.newScope (
            self:
            {
              inherit flake inputs system;
              platformSource = import ./lib/platform-source.nix {
                inherit (pkgs) stdenv fetchurl;
              };
              # bun2nix builder set (hook, fetchBunDeps, ...); the `bun2nix`
              # scope attribute is the CLI package.
              bun2nixLib = (pkgs.extend inputs.bun2nix.overlays.default).bun2nix;
            }
            // lib.genAttrs packageNames (
              name:
              let
                dir = ./packages + "/${name}";
              in
              if builtins.pathExists (dir + "/default.nix") then
                callWith {
                  inherit
                    pkgs
                    packages
                    flake
                    inputs
                    system
                    ;
                } (import dir)
              else
                self.callPackage (dir + "/package.nix") { }
            )
          );

          # Only the packages, without the scope plumbing and helpers.
          packages = lib.genAttrs packageNames (name: scope.${name});
        in
        packages;

      # Every package under packages/, independent of the current platform.
      allPackages = eachSystem (system: mkPackagesFor pkgsFor.${system});

      # Only expose packages that build on the given platform.
      available =
        system: pkg:
        lib.meta.availableOn pkgsFor.${system}.stdenv.hostPlatform pkg && !(pkg.meta.broken or false);

      packages = eachSystem (system: lib.filterAttrs (_name: available system) allPackages.${system});

      devShells = eachSystem (system: {
        default = callWith {
          pkgs = pkgsFor.${system};
          perSystem = {
            self = allPackages.${system};
          };
          inherit flake inputs system;
        } (import ./devshell.nix);
      });
    in
    {
      lib = import ./lib { inherit inputs; };

      inherit packages devShells;

      overlays.shared-nixpkgs = import ./overlays/shared-nixpkgs.nix {
        inherit mkPackagesFor;
      };

      formatter = eachSystem (system: allPackages.${system}.formatter);

      checks = eachSystem (
        system:
        lib.mapAttrs' (name: pkg: lib.nameValuePair "pkgs-${name}" pkg) packages.${system}
        // lib.genAttrs checkNames (
          name:
          callWith {
            pkgs = pkgsFor.${system};
            inherit flake inputs system;
          } (import (./checks + "/${name}.nix"))
        )
        // {
          devshell-default = devShells.${system}.default;
        }
      );
    };
}
