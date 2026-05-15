{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  wrapBuddy,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  pname = "grok";
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x86_64";
    aarch64-linux = "linux-aarch64";
    aarch64-darwin = "macos-aarch64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://storage.googleapis.com/grok-build-public-artifacts/cli/grok-${version}-${platformSuffix}";
    hash = hashes.${platform};
  };

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapBuddy
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/libexec/grok/grok

    makeWrapper $out/libexec/grok/grok $out/bin/grok \
      --argv0 grok \
      --add-flags --no-auto-update

    makeWrapper $out/libexec/grok/grok $out/bin/agent \
      --argv0 agent \
      --add-flags --no-auto-update

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Grok Build, xAI's agentic coding tool";
    homepage = "https://x.ai";
    changelog = "https://x.ai";
    license = licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ryoppippi ];
    mainProgram = "grok";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
