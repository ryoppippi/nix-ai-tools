{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  versionCheckHook,
}:

buildNpmPackage rec {
  pname = "nanocoder";
  version = "1.28.0";

  src = fetchFromGitHub {
    owner = "Nano-Collective";
    repo = "nanocoder";
    rev = "v${version}";
    hash = "sha256-hs6Do1ObudylPe398ZxwZX3S4fHvcPhTHShf9ZcHe1E=";
  };

  npmDeps = null;
  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-ZJn7pK/tufjhlEaKNI8lbRB3l+FHl+5qAXJoE+raSPM=";
  };

  nativeBuildInputs = [ pnpm ];
  npmConfigHook = pnpmConfigHook;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  dontNpmPrune = true; # hangs forever on both Linux/darwin

  # pnpm links the plugins/vscode workspace package into node_modules, but
  # npm pack does not ship plugins/, leaving a dangling symlink in $out.
  preFixup = ''
    rm -f $out/lib/node_modules/@nanocollective/nanocoder/node_modules/.pnpm/node_modules/nanocoder-vscode
  '';

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "A beautiful local-first coding agent running in your terminal - built by the community for the community ⚒";
    homepage = "https://github.com/Nano-Collective/nanocoder";
    changelog = "https://github.com/Nano-Collective/nanocoder/releases";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "nanocoder";
  };
}
