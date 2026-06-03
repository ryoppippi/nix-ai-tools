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
  version = "1.2.1";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "gascity";
    rev = "v${version}";
    hash = "sha256-q9ehkxbkq4bnGn8vB0OM/8MJRk6zgVCBLnlrmHx7/RI=";
  };

  vendorHash = "sha256-jKuPfAilxCndnkOCJf475wLh0DyxZxXQ33c+7nwFYzM=";

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
