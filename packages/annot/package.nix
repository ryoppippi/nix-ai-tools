{
  lib,
  flake,
  stdenv,
  rustPlatform,
  fetchFromGitHub,

  jq,
  moreutils,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs,
  cargo-tauri,
  pkg-config,
  wrapGAppsHook3,
  makeBinaryWrapper,

  libsoup_3,
  openssl,
  webkitgtk_4_1,

  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "annot";
  version = "0.17.0";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "denolehov";
    repo = "annot";
    tag = "v${finalAttrs.version}";
    hash = "sha256-nnryODRspvZMiScCUoX/ErGSzFgh35zHX/i2gc90dfk=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-rMDkGVgZZan8yyIlTr9cyNhnqHpYjObyFktCgs++k20=";
  };

  postPatch = ''
    jq '.bundle.createUpdaterArtifacts = false' src-tauri/tauri.conf.json | sponge src-tauri/tauri.conf.json
  '';

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoHash = "sha256-aG+gC4AK/swUBrYsIIlyP0E7Lezo41YStLKee/7FgYQ=";

  nativeBuildInputs = [
    jq
    moreutils
    pnpmConfigHook
    pnpm_10
    nodejs
    cargo-tauri.hook
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    pkg-config
    wrapGAppsHook3
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    makeBinaryWrapper
  ];

  buildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      libsoup_3
      openssl
      webkitgtk_4_1
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      openssl
    ];

  # pnpmConfigHook runs with --ignore-scripts, so the postinstall that copies
  # Excalidraw fonts from node_modules into static/ must be run manually.
  preBuild = ''
    node scripts/copy-excalidraw-fonts.js
  '';

  # Disable automatic wrapper to handle it manually per platform
  dontWrapGApps = stdenv.hostPlatform.isLinux;

  postFixup =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      wrapGApp "$out/bin/annot"
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      makeWrapper "$out/Applications/annot.app/Contents/MacOS/annot" "$out/bin/annot"
    '';

  passthru = {
    updateScript = nix-update-script { };
    category = "Code Review";
  };

  meta = {
    description = "Human-in-the-loop annotation tool for AI workflows";
    changelog = "https://github.com/denolehov/annot/releases/tag/v${finalAttrs.version}";
    longDescription = ''
      annot is an annotation tool for human-in-the-loop AI workflows. AI
      agents work fast, but vague feedback is a lossy channel. When an agent
      drafts a plan, proposes a refactor, or generates code, annot provides a
      moment of structured review: it opens a native window, you annotate
      specific lines with located, typed comments, then it closes and returns
      structured output to the agent.

      annot can be used as a standalone CLI (open a file, annotate, get
      output) or as an MCP server, allowing AI agents to block on human
      review mid-workflow. It supports reviewing files, diffs, and
      agent-generated content, with optional exit modes so the human can
      signal approval, rejection, or custom next steps.
    '';
    homepage = "https://github.com/denolehov/annot";
    license = lib.licenses.agpl3Only;
    mainProgram = "annot";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ fraggerfox ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
