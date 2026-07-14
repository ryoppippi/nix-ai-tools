{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  go-bin,
  beads,
  dolt,
  flock,
  gitMinimal,
  jq,
  lsof,
  procps,
  tmux,
  versionCheckHook,
}:

assert lib.versionAtLeast dolt.version "2.1.0";

(buildGoModule.override { go = go-bin; }) rec {
  pname = "gascity";
  version = "1.3.5";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "gascity";
    tag = "v${version}";
    hash = "sha256-LWz0YTcDNnrqTcF9bL+SINuyfO3ZIAVelUVYsZAflto=";
  };

  vendorHash = "sha256-HbeqaI/fTYMSaQdA4tn+s5dx9ehUY+/Cw4Z7bRLR4/U=";

  env.CGO_ENABLED = "0";

  nativeBuildInputs = [ makeWrapper ];

  subPackages = [ "cmd/gc" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=nixpkgs"
    "-X main.date=1970-01-01T00:00:00Z"
  ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/gc \
      --prefix PATH : ${
        lib.makeBinPath [
          beads
          dolt
          flock
          gitMinimal
          jq
          lsof
          procps
          tmux
        ]
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = [ "version" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Orchestration-builder SDK for multi-agent coding workflows";
    homepage = "https://github.com/gastownhall/gascity";
    changelog = "https://github.com/gastownhall/gascity/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zaninime ];
    mainProgram = "gc";
    platforms = dolt.meta.platforms;
  };
}
