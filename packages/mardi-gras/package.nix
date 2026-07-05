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
  version = "0.26.0";

  src = fetchFromGitHub {
    owner = "quietpublish";
    repo = "mardi-gras";
    tag = "v${version}";
    hash = "sha256-TL6m3WaNomZ4VYXbbACQb9YtGNYB81N2xBBLGH5vlRw=";
  };

  vendorHash = "sha256-GE1fG7OugQy783e4JZG19DvZ6DDU6vjAr/cbgAncZmA=";

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
