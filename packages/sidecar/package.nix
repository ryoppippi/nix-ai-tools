{
  lib,
  flake,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

buildGoModule rec {
  pname = "sidecar";
  version = "0.86.0";

  src = fetchFromGitHub {
    owner = "marcus";
    repo = "sidecar";
    tag = "v${version}";
    hash = "sha256-zhSWGKmTgDKSwQLhax2XoXJXnyJ+cdhK4M0bcHAW8lE=";
  };

  vendorHash = "sha256-vMDUw6zA6OpH866VdtCuFu2cbHt5NnA6k4WtQjZTpxs=";

  subPackages = [ "cmd/sidecar" ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${version}"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Terminal-based development companion for AI coding agents";
    homepage = "https://github.com/marcus/sidecar";
    changelog = "https://github.com/marcus/sidecar/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ afterthought ];
    mainProgram = "sidecar";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
