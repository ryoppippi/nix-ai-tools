{
  lib,
  flake,
  stdenv,
  fetchFromGitHub,
  bun2nix,
  bun,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation {
  pname = "hunk";
  inherit version;

  src = fetchFromGitHub {
    owner = "modem-dev";
    repo = "hunk";
    tag = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nix.hook
    bun
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  dontUseBunBuild = true;
  dontUseBunInstall = true;
  dontRunLifecycleScripts = true;
  # `bun build --compile` embeds the JS bundle inside the executable;
  # stripping corrupts it.
  dontStrip = true;

  # Pin every dependency to the exact version vendored in bun.nix.
  # bun's offline resolver refuses semver ranges (^/~) when only one
  # version is present in the store, so collapse them to exact pins.
  postPatch = ''
    for f in package.json packages/*/package.json; do
      if [ -f "$f" ]; then
        sed -i 's/: "\^/: "/g; s/: "~/: "/g' "$f"
      fi
    done
    sed -i 's/: "\^/: "/g; s/: "~/: "/g' bun.lock
  '';

  buildPhase = ''
    runHook preBuild

    mkdir -p .bun-tmp .bun-install
    BUN_TMPDIR=$PWD/.bun-tmp \
    BUN_INSTALL=$PWD/.bun-install \
    ${lib.getExe bun} build --compile "./src/main.tsx" --outfile "hunk-bin"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ./hunk-bin $out/bin/hunk
    # The binary locates the bundled review skill by walking ancestor
    # directories of process.execPath looking for skills/hunk-review/SKILL.md
    # (src/core/paths.ts), so it must live at $out/skills.
    cp -r ./skills $out/
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Code Review";

  meta = with lib; {
    description = "Terminal diff viewer for agentic changesets";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ benvinegar ];
    mainProgram = "hunk";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
