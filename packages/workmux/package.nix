{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  llvmPackages,
  versionCheckHook,
  versionCheckHomeHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "workmux";
  version = "0.1.224";

  src = fetchFromGitHub {
    owner = "raine";
    repo = "workmux";
    tag = "v${version}";
    hash = "sha256-HnqP0wvVk3q5nTXzGmFQ96cDqnCQ2zjs4TtO1ZxU80g=";
  };

  cargoHash = "sha256-1VpvzqL/7qbud2fR0s6zl11RdN/QuHkEqetAM4y0tCQ=";

  nativeBuildInputs = [
    installShellFiles
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ llvmPackages.lld ];

  # nixpkgs' classic ld64 crashes in its stubs pass when linking the
  # mac-notification-sys Objective-C object (NixOS/nixpkgs#540450); use lld
  # on darwin until the ld64 fix (NixOS/nixpkgs#536365) lands.
  env = lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    NIX_CFLAGS_LINK = "-fuse-ld=lld";
  };

  # Some tests require filesystem access outside the sandbox
  doCheck = false;

  postInstall =
    lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      export HOME=$(mktemp -d)
      installShellCompletion --cmd workmux \
        --bash <($out/bin/workmux completions bash) \
        --fish <($out/bin/workmux completions fish) \
        --zsh <($out/bin/workmux completions zsh)
    ''
    + ''
      # Install Claude Code skills shipped with workmux so users can
      # symlink $out/share/workmux/skills/* into ~/.claude/skills/
      install -d $out/share/workmux
      cp -r skills $out/share/workmux/skills
    '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Git worktrees + tmux windows for zero-friction parallel dev";
    homepage = "https://github.com/raine/workmux";
    changelog = "https://github.com/raine/workmux/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "workmux";
    platforms = platforms.all;
  };
}
