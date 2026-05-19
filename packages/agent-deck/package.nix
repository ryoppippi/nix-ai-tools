{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
  versionCheckHomeHook,
  git,
}:

buildGoModule rec {
  pname = "agent-deck";
  version = "1.9.20";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-aTnQ+rCvN/dWcu0RrSfMo4oApILYg/wdQzJfsJhzwiE=";
  };

  vendorHash = "sha256-/7hzCID4Vu9z6VHN7NiAjyoZPEBPHet4fJdh/VSZaGQ=";

  subPackages = [ "cmd/agent-deck" ];

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  doCheck = true;

  # The OBS-01 wiring test compiles the binary, launches the full TUI in a
  # subprocess and waits for it to write debug.log. The TUI bails in the
  # sandbox (no tmux/terminal), so debug.log never appears. The test guards
  # the subprocess arm with testing.Short(), so honour that.
  # TestValidatePluginFlags_TelegramForkAccepted expects a hardcoded plugin
  # catalog that doesn't match the built-in catalog in this version.
  # TestValidatePluginFlags_EmptyCatalogActionableError leaks plugin catalog
  # state from TelegramForkAccepted (a package-level cache is not reset
  # between tests). Both are upstream test isolation bugs; skip them.
  checkFlags = [
    "-short"
    "-skip=TestValidatePluginFlags_TelegramForkAccepted|TestValidatePluginFlags_EmptyCatalogActionableError"
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export PATH="${git}/bin:$PATH"
  '';

  doInstallCheck = true;

  ldflags = [
    "-s"
    "-w"
    # Upstream renamed the variable from main.version to main.Version in 1.9.x.
    "-X=main.Version=${version}"
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Your AI agent command center";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    changelog = "https://github.com/asheshgoplani/agent-deck/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ garbas ];
    mainProgram = "agent-deck";
  };
}
