{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  beads,
  dolt,
  gitMinimal,
  icu,
  sqlite,
  tmux,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "gastown";
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "gastown";
    tag = "v${version}";
    hash = "sha256-U3spPM8tKp5aoWy+l1qpRtrfIppkQAPSp1z50FQUv2I=";
  };

  vendorHash = "sha256-PQT/Xq9na3vI8Oy9INBYJf3GsiN5IxAVCxrNLhyIpO8=";

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ icu ];

  subPackages = [ "cmd/gt" ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/steveyegge/gastown/internal/cmd.Version=${version}"
    "-X=github.com/steveyegge/gastown/internal/cmd.Build=release"
    "-X=github.com/steveyegge/gastown/internal/cmd.BuiltProperly=1"
  ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/gt \
      --prefix PATH : ${
        lib.makeBinPath [
          beads
          dolt
          gitMinimal
          sqlite
          tmux
        ]
      }
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Gas Town - multi-agent workspace manager";
    homepage = "https://github.com/gastownhall/gastown";
    changelog = "https://github.com/gastownhall/gastown/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zaninime ];
    mainProgram = "gt";
    platforms = platforms.unix;
  };
}
