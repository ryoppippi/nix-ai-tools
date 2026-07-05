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
  version = "1.3.3";

  src = fetchFromGitHub {
    owner = "gastownhall";
    repo = "gascity";
    tag = "v${version}";
    hash = "sha256-hmgDFEU2+KOgJmHKUxHW5Kp/c1F7+qMLHzWNWjDQgcY=";
  };

  vendorHash = "sha256-efJQXI9qy6zLuP2HPUzydlEvRB7XRpMYQir5woPfs90=";

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
