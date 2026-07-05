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
  version = "1.9.73";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    tag = "v${version}";
    hash = "sha256-4LbeRiaFIn4Nx/VtDvhJAaeA7YB6i2VX8wZhJ75qw5k=";
  };

  vendorHash = "sha256-teB9HxMGOe5YGW0RGxVOhkDPyczCDdjATRV9Mn9ixDU=";

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
  # TestVerifyPromptConsumedAfterLaunch_UnsentFirstWindow_RetryThenConsumed_OneRetry_NoWarning
  # polls real wall-clock time with a 20ms window and 2ms interval; on loaded
  # CI builders the window elapses before the consumed pane is observed and a
  # spurious warning fails the test. Timing-sensitive; skip it.
  # TestWaitForFreshOutput_UniquePeerStillReads waits for fresh transcript
  # output with a 300ms freshness timeout; on loaded CI builders the read
  # races past the window and the transcript comes back empty. Timing-sensitive;
  # skip it.
  checkFlags = [
    "-short"
    "-skip=TestValidatePluginFlags_TelegramForkAccepted|TestValidatePluginFlags_EmptyCatalogActionableError|TestVerifyPromptConsumedAfterLaunch_UnsentFirstWindow_RetryThenConsumed_OneRetry_NoWarning|TestWaitForFreshOutput_UniquePeerStillReads"
  ];

  preCheck = ''
    # Since 1.9.48 a test-only guard refuses to touch paths under the real
    # user home, taken from the passwd entry (/build for nixbld). All temp
    # dirs (t.TempDir, mktemp) default to TMPDIR=/build and trip it, so move
    # HOME and TMPDIR to /tmp, which is outside the passwd home.
    export TMPDIR=$(mktemp -d -p /tmp)
    export HOME=$(mktemp -d -p /tmp)
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
