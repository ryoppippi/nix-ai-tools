{
  lib,
  flake,
  buildDotnetModule,
  dotnetCorePackages,
  fetchFromGitHub,
  versionCheckHook,
}:

buildDotnetModule rec {
  pname = "officecli";
  version = "1.0.126";

  src = fetchFromGitHub {
    owner = "iOfficeAI";
    repo = "OfficeCLI";
    tag = "v${version}";
    hash = "sha256-6c0nB/J93f0g0Mqg7HEc7GAd6TDoDMgyxx5GM6pIaAM=";
  };

  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  selfContainedBuild = true;
  projectFile = "src/officecli/officecli.csproj";
  executables = [ "officecli" ];
  nugetDeps = ./deps.json;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Utilities";

  meta = with lib; {
    description = "CLI for creating and editing Office Open XML documents";
    homepage = "https://github.com/iOfficeAI/OfficeCLI";
    changelog = "https://github.com/iOfficeAI/OfficeCLI/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    mainProgram = "officecli";
    platforms = platforms.unix;
  };
}
