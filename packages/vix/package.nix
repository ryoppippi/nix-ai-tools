{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
  pkg-config,
}:

buildGoModule rec {
  pname = "vix";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "get-vix";
    repo = "vix";
    rev = "v${version}";
    hash = "sha256-dlW07swW66Qkc7K0Ugt+dyqJnHE4cKiPOXIlEkAqiO8=";
  };

  # source already has vendor folder
  vendorHash = null;

  subPackages = [
    "cmd/vix"
    "cmd/vixd"
  ];

  nativeBuildInputs = [ pkg-config ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X github.com/get-vix/vix/internal/ui.Version=${version}"
  ];

  doCheck = true;
  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Sleek, Fast and Token Efficient AI Coding Agent";
    homepage = "https://github.com/get-vix/vix";
    changelog = "https://github.com/get-vix/vix/releases/tag/v${version}";
    license = licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [ daspk04 ];
    mainProgram = "vix";
    platforms = platforms.unix;
  };
}
