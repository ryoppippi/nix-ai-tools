{
  lib,
  flake,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  electron_40,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  python3,
}:

let
  # Upstream pins electron ^39, but electron_39 is EOL/insecure in nixpkgs.
  # Electron majors are backwards compatible enough for this app; the build
  # guard below catches the day upstream jumps ahead of what we ship.
  electron = electron_40;
in
buildNpmPackage rec {
  pname = "hermes-desktop";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "fathah";
    repo = "hermes-desktop";
    tag = "v${version}";
    hash = "sha256-qh+SqJ3ihlaArqzDWfClBGtR4TlE6dA9BSp+oSJ7iRk=";
  };

  npmDepsHash = "sha256-AXW7PmVN5meC2jKu5Zn6LpdfaedY72nnIB8XGBHt6oE=";
  npmDepsFetcherVersion = 2;

  # Upstream postinstall runs electron-builder install-app-deps and husky;
  # neither works in the sandbox. Native modules are rebuilt explicitly below.
  npmFlags = [ "--ignore-scripts" ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  nativeBuildInputs = [
    makeWrapper
    python3 # node-gyp needs it to rebuild better-sqlite3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ copyDesktopItems ];

  buildPhase = ''
    runHook preBuild

    # Fail loudly if upstream moves to an Electron major newer than ours.
    upstream_electron=$(node -p "require('./package.json').devDependencies.electron")
    upstream_major=''${upstream_electron#^}
    upstream_major=''${upstream_major%%.*}
    nix_major=${lib.versions.major electron.version}
    if (( upstream_major > nix_major )); then
      echo "error: upstream expects electron $upstream_electron but we provide ${electron.version}"
      echo "Update the electron input in package.nix to match."
      exit 1
    fi

    # better-sqlite3 ships no prebuilds for Electron's ABI; compile it
    # against the Electron headers so the main process can load it.
    export npm_config_nodedir=${electron.headers}
    npm rebuild better-sqlite3 --build-from-source

    npx electron-vite build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/hermes-desktop $out/bin

    cp -r out package.json $out/share/hermes-desktop/

    # Runtime dependencies for the main process: electron-vite externalizes
    # everything in package.json "dependencies" (better-sqlite3, i18next,
    # electron-updater, ...), so they must exist in node_modules.
    npm prune --omit=dev
    # Drop node-gyp intermediates; only the compiled addon is needed.
    find node_modules/better-sqlite3/build -mindepth 1 -maxdepth 1 ! -name Release -exec rm -rf {} +
    find node_modules/better-sqlite3/build/Release -mindepth 1 ! -name better_sqlite3.node -exec rm -rf {} +
    cp -r node_modules $out/share/hermes-desktop/

    install -Dm644 build/icon.png $out/share/icons/hicolor/512x512/apps/hermes-desktop.png

    # app.isPackaged stays false on purpose: upstream skips its
    # electron-updater code path in that case, which is what we want for a
    # store-managed install.
    makeWrapper ${lib.getExe electron} $out/bin/hermes-desktop \
      --add-flags $out/share/hermes-desktop \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --inherit-argv0

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "hermes-desktop";
      desktopName = "Hermes Agent";
      comment = "Self-improving AI assistant desktop app";
      exec = "hermes-desktop %U";
      icon = "hermes-desktop";
      categories = [ "Utility" ];
      startupWMClass = "hermes-desktop";
    })
  ];

  passthru.category = "AI Assistants";

  meta = with lib; {
    description = "Desktop companion for Hermes Agent";
    homepage = "https://github.com/fathah/hermes-desktop";
    changelog = "https://github.com/fathah/hermes-desktop/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ smdex ];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "hermes-desktop";
  };
}
