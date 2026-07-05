{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  cmake,
  openssl,
  libxcb,
  dbus,
  versionCheckHook,
  cacert,
  librusty_v8,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
in
rustPlatform.buildRustPackage rec {
  pname = "goose-cli";
  inherit (versionData) version cargoHash;

  src = fetchFromGitHub {
    # Upstream moved from block/goose to aaif-goose/goose.
    owner = "aaif-goose";
    repo = "goose";
    tag = "v${version}";
    inherit (versionData) hash;
  };

  nativeBuildInputs = [
    pkg-config
    # llama-cpp-sys-2 builds llama.cpp via cmake and generates bindings with
    # bindgen, which needs libclang at build time.
    cmake
    rustPlatform.bindgenHook
  ];

  # The cmake setup hook would otherwise try to configure the cargo project
  # itself; llama-cpp-sys-2 invokes cmake on its own.
  dontUseCmakeConfigure = true;

  buildInputs = [
    openssl
    libxcb
    dbus
  ];

  # reqwest-based tests need a CA bundle to construct HTTP clients.
  nativeCheckInputs = [ cacert ];

  # The v8 package will try to download a `librusty_v8.a` release at build time to our read-only filesystem
  # To avoid this we pre-download the file and export it via RUSTY_V8_ARCHIVE
  env.RUSTY_V8_ARCHIVE = librusty_v8;

  # Build only the CLI package
  cargoBuildFlags = [
    "--package"
    "goose-cli"
  ];

  # Enable tests with proper environment
  doCheck = true;
  checkPhase = ''
    export HOME=$(mktemp -d)
    export XDG_CONFIG_HOME=$HOME/.config
    export XDG_DATA_HOME=$HOME/.local/share
    export XDG_STATE_HOME=$HOME/.local/state
    export XDG_CACHE_HOME=$HOME/.cache
    mkdir -p $XDG_CONFIG_HOME $XDG_DATA_HOME $XDG_STATE_HOME $XDG_CACHE_HOME

    # Run tests for goose-cli package only.
    # test_verify_provenance_warns_on_missing_attestation needs network access.
    cargo test --package goose-cli --release -- \
      --skip commands::update::tests::test_verify_provenance_warns_on_missing_attestation
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "CLI for Goose - a local, extensible, open source AI agent that automates engineering tasks";
    homepage = "https://github.com/aaif-goose/goose";
    changelog = "https://github.com/aaif-goose/goose/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "goose";
  };
}
