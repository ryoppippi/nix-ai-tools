{
  lib,
  buildNpmPackage,
  bun,
  fetchurl,
  fd,
  ripgrep,
  runCommand,
  stdenv,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # napi-rs target triple, e.g. darwin-arm64, linux-x64-gnu
  napiTargets = {
    aarch64-darwin = "darwin-arm64";
    aarch64-linux = "linux-arm64-${if stdenv.hostPlatform.isMusl then "musl" else "gnu"}";
    x86_64-linux = "linux-x64-${if stdenv.hostPlatform.isMusl then "musl" else "gnu"}";
  };
  napiTarget =
    napiTargets.${stdenv.hostPlatform.system}
      or (throw "Unsupported Pi platform: ${stdenv.hostPlatform.system}");
  clipboardNativeFile = "clipboard.${napiTarget}.node";

  # Create a source with package-lock.json included
  srcWithLock = runCommand "pi-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    rm -f $out/npm-shrinkwrap.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  inherit version;
  pname = "pi";

  src = srcWithLock;

  npmDepsHash = versionData.npmDepsHash;
  makeCacheWritable = true;

  # The package from npm is already built
  dontNpmBuild = true;

  nativeBuildInputs = [ bun ];

  # Compile a standalone binary like upstream's build:binary script. Running
  # dist/bun/cli.js directly with Bun breaks extension module aliasing (#6794).
  preInstall = ''
    # Upstream embeds the worker as ./src/utils/image-resize-worker.ts and
    # loads it by that path at runtime; the npm tarball only ships dist/.
    mkdir -p src/utils src/modes src/core
    echo 'import "../../dist/utils/image-resize-worker.js";' > src/utils/image-resize-worker.ts
    ln -s ../../dist/modes/interactive src/modes/interactive
    ln -s ../../dist/core/export-html src/core/export-html

    bun build --compile ./dist/bun/cli.js ./src/utils/image-resize-worker.ts --outfile dist/pi
  '';

  postInstall = ''
    pkgdir=$out/libexec/pi

    # The binary embeds all modules; assemble the release layout that
    # upstream's scripts/build-binaries.sh ships.
    rm -rf "$out/lib" "$out/bin"
    mkdir -p "$out/bin" "$pkgdir/theme" "$pkgdir/assets"
    cp dist/pi "$pkgdir/"
    cp package.json README.md CHANGELOG.md "$pkgdir/"
    # Mirror scripts/build-binaries.sh: Bun cannot embed these runtime assets.
    mkdir -p "$pkgdir/node_modules/@mariozechner"
    cp -r node_modules/@mariozechner/clipboard "$pkgdir/node_modules/@mariozechner/"
    cp -r node_modules/@mariozechner/clipboard-${napiTarget} "$pkgdir/node_modules/@mariozechner/"
    cp node_modules/@mariozechner/clipboard-${napiTarget}/${clipboardNativeFile} \
      "$pkgdir/node_modules/@mariozechner/clipboard/"
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      mkdir -p "$pkgdir/native/darwin/prebuilds/${napiTarget}"
      cp node_modules/@earendil-works/pi-tui/native/darwin/prebuilds/${napiTarget}/darwin-modifiers.node \
        "$pkgdir/native/darwin/prebuilds/${napiTarget}/"
    ''}
    cp node_modules/@silvia-odwyer/photon-node/photon_rs_bg.wasm "$pkgdir/"
    cp dist/modes/interactive/theme/*.json "$pkgdir/theme/"
    cp dist/modes/interactive/assets/* "$pkgdir/assets/"
    cp -r dist/core/export-html "$pkgdir/"
    cp -r docs examples "$pkgdir/"
    # Keep patchShebangs from pulling Node into the closure via shipped scripts.
    find "$pkgdir" -name '*.js' -exec chmod -x {} +

    makeWrapper "$pkgdir/pi" "$out/bin/pi" \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR "$pkgdir" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  postInstallCheck = ''
    ${bun}/bin/bun --eval 'require(process.argv[1])' \
      "$out/libexec/pi/node_modules/@mariozechner/clipboard/${clipboardNativeFile}"
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    ${bun}/bin/bun --eval 'require(process.argv[1])' \
      "$out/libexec/pi/native/darwin/prebuilds/${napiTarget}/darwin-modifiers.node"
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/earendil-works/pi";
    changelog = "https://github.com/earendil-works/pi/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ aos ];
    platforms = builtins.attrNames napiTargets;
    mainProgram = "pi";
  };
}
