{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
  nodejs,
  versionCheckHook,
  versionCheckHomeHook,
}:

stdenv.mkDerivation rec {
  pname = "ccusage";
  version = "19.0.2";

  src = fetchzip {
    url = "https://registry.npmjs.org/ccusage/-/ccusage-${version}.tgz";
    hash = "sha256-vZwWiVEQG6sbc4Z9IIgN9hXS2FvkMSW/7n09/o7ZI/I=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp -r dist $out/lib

    makeWrapper ${nodejs}/bin/node $out/bin/ccusage \
      --add-flags $out/lib/cli.js

    runHook postInstall
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Analyze coding agent CLI token usage and costs from local data";
    homepage = "https://github.com/ryoppippi/ccusage";
    changelog = "https://github.com/ryoppippi/ccusage/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "ccusage";
    platforms = platforms.all;
  };
}
