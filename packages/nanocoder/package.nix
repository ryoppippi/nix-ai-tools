{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  # Lockfile predates pnpm 11's stricter overrides validation
  pnpm_10,
  pnpmConfigHook,
  versionCheckHook,
}:

let
  pnpm = pnpm_10;
in
buildNpmPackage rec {
  pname = "nanocoder";
  version = "1.25.2";

  src = fetchFromGitHub {
    owner = "Mote-Software";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-Ccho0mKv1unmzmvwcbK7c0hA7BQebFUWKSMug21NFzg=";
    postFetch = ''
      rm -f $out/pnpm-workspace.yaml
    '';
  };

  npmDeps = null;
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-FFRHvQ5HKQ9v2Wwh8W7ILWb0FlLrVD+ktYBwjNVAfrI=";
  };

  nativeBuildInputs = [ pnpm ];
  npmConfigHook = pnpmConfigHook;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  dontNpmPrune = true; # hangs forever on both Linux/darwin

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "A beautiful local-first coding agent running in your terminal - built by the community for the community ⚒";
    homepage = "https://github.com/Mote-Software/nanocoder";
    changelog = "https://github.com/Mote-Software/nanocoder/releases";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "nanocoder";
  };
}
