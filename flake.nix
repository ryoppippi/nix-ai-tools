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

      systems = import inputs.systems;
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

      pkgsFor = eachSystem (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      # Every package under packages/, independent of the current platform.
      # Cross-package references go through `perSystem.self.<name>`.
      allPackages = eachSystem (
        system:
        let
          pkgs = pkgsFor.${system};
          perSystem = {
            self = packages;
          };
          packages = lib.genAttrs packageNames (
            name:
            callWith {
              inherit
                pkgs
                perSystem
                flake
                inputs
                system
                ;
            } (import (./packages + "/${name}"))
          );
        in
        packages
      );

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
