{
  lib,
  flake,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  makeWrapper,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  pnpm = pnpm_10;

  pnpmWorkspaces = [
    "@mindfoldhq/trellis-core"
    "@mindfoldhq/trellis"
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "trellis";
  version = "0.6.8";

  src = fetchFromGitHub {
    owner = "mindfold-ai";
    repo = "trellis";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CXus8UoIZlsG2IIBcYg35MKVF+UnD8HFNKLlZoiO6GQ=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm pnpmWorkspaces;
    hash = "sha256-DFPIIQbxJpN6FTcOUBEWu5E5lEotGX2eqzIlieTMlyY=";
    fetcherVersion = 3;
  };

  inherit pnpmWorkspaces;

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild

    pnpm --filter @mindfoldhq/trellis-core build
    pnpm --filter @mindfoldhq/trellis build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    pnpm config set inject-workspace-packages true
    pnpm --filter @mindfoldhq/trellis --prod --ignore-scripts deploy $out/lib/trellis

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/trellis \
      --add-flags $out/lib/trellis/bin/trellis.js \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}
    ln -s $out/bin/trellis $out/bin/tl

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Memory & Code Intelligence";

  meta = {
    description = "An out-of-the-box engineering framework for AI coding.";
    homepage = "https://github.com/mindfold-ai/trellis";
    changelog = "https://github.com/mindfold-ai/trellis/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ hobr ];
    mainProgram = "trellis";
    platforms = lib.platforms.all;
  };
})
