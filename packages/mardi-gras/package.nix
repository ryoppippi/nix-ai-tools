{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  go-bin,
  versionCheckHook,
  versionCheckHomeHook,
}:

buildGoModule.override { go = go-bin; } rec {
  pname = "mardi-gras";
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "quietpublish";
    repo = "mardi-gras";
    rev = "v${version}";
    hash = "sha256-59JJe2D41NElLzKva0VRhygRLN1MXc2y0DzHEljgg8I=";
  };

  vendorHash = "sha256-7+5lM5qvBFhKKgm7gDcmigVQlA/QFmvQ+bsgbTB1sms=";

  subPackages = [ "cmd/mg" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Terminal UI for Beads issue tracking with a parade-inspired workflow view";
    homepage = "https://github.com/quietpublish/mardi-gras";
    changelog = "https://github.com/quietpublish/mardi-gras/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "mg";
    platforms = platforms.unix;
  };
}
