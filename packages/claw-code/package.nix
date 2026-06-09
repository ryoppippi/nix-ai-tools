{
  lib,
  flake,
  fetchFromGitHub,
  rustPlatform,
  git,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "claw-code";
  version = "0-unstable-2026-06-08";

  src = fetchFromGitHub {
    owner = "ultraworkers";
    repo = "claw-code";
    rev = "d229a9b022d4845d28a728677e6a6b7c22ec5a2e";
    hash = "sha256-mP7nd9sMsjGD3cOF08C4PW3Y/2EcDGoPlhmcSSTdmeQ=";
  };

  sourceRoot = "source/rust";

  cargoHash = "sha256-Acaycrxm3e87dx3P7NdWnivopF4xxaMi3PPbpSefEyY=";

  cargoBuildFlags = [
    "--package"
    "rusty-claude-cli"
  ];
  cargoTestFlags = cargoBuildFlags;

  # Upstream's #[cfg(test)] block in rusty-claude-cli/src/main.rs is broken
  # at this rev (ApiError::Api initializers missing the new suggested_action
  # field). The release binary compiles fine, so skip cargo test until
  # upstream catches up.
  doCheck = false;

  nativeCheckInputs = [ git ];

  preCheck = ''
    export HOME=$TMPDIR
  '';

  checkFlags = [
    # broken upstream at this rev: tool allow-list assertions out of sync with implementation
    "--skip=tests::rejects_unknown_allowed_tools"
    "--skip=tests::build_runtime_plugin_state_discovers_mcp_tools_and_surfaces_pending_servers"
    # integration harness expects scripted plugin fixtures not present in sandbox
    "--skip=clean_env_cli_reaches_mock_anthropic_service_across_scripted_parity_scenarios"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  # Upstream has no tagged release yet; we track an unstable rev. The binary
  # reports the Cargo workspace.package.version (e.g. 0.1.0), so compare
  # against that rather than our `0-unstable-<date>` derivation version.
  preVersionCheck = ''
    version=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n1)
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Claude Code rewrite CLI built from the official claw-code Rust workspace";
    homepage = "https://github.com/ultraworkers/claw-code";
    changelog = "https://github.com/ultraworkers/claw-code/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "claw";
    platforms = lib.platforms.unix;
  };
}
