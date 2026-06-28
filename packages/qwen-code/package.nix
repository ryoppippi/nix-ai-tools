{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  git,
  ripgrep,
  pkg-config,
  glib,
  libsecret,
  darwinOpenptyHook,
  clang_20,
  versionCheckHook,
}:

buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "qwen-code";
  version = "0.19.3";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-MoAfHM+d1usRqmuHu/yJeFcd/ipt95FYrBSlsmE+DZA=";
  };

  npmDepsHash = "sha256-eKsBaUoMMMa5lAokoKu8ZQYOnxWaekZVg7GaHfgxiR0=";
  makeCacheWritable = true;

  nativeBuildInputs = [
    pkg-config
    git
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    clang_20 # Works around node-addon-api constant expression issue with clang 21+ (keytar)
    darwinOpenptyHook # Fixes node-pty openpty/forkpty build issue
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  buildPhase = ''
    runHook preBuild

    npm run generate
    # The CLI esbuild bundle resolves imports against workspace dist/ output,
    # so build the workspaces it depends on first (subset of upstream's
    # scripts/build.js buildOrder; we skip webui/sdk/vscode as the bundled
    # CLI does not pull them in). The CLI registry auto-imports every channel
    # adapter under packages/channels, so glob them instead of hardcoding:
    # upstream adds new channels between releases (e.g. feishu in 0.17.0).
    npm run build --workspace=packages/web-templates
    npm run build --workspace=packages/channels/base
    for ws in packages/channels/*; do
      if [ -d "$ws" ] && [ "$ws" != packages/channels/base ]; then
        npm run build --workspace=$ws
      fi
    done
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    # Install production dependencies only
    npm prune --production
    cp -r node_modules $out/share/qwen-code/
    # Remove broken symlinks that cause issues in Nix environment
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli.js $out/bin/qwen

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with lib.maintainers; [
      zimbatm
      lonerOrz
    ];
    platforms = lib.platforms.all;
    mainProgram = "qwen";
  };
})
