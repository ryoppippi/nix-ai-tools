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
  linuxClipboardAbi = if stdenv.hostPlatform.isMusl then "musl" else "gnu";
  platformsBySystem = {
    aarch64-darwin = {
      clipboardNativePackage = "clipboard-darwin-arm64";
      clipboardNativeFile = "clipboard.darwin-arm64.node";
      tuiNativeTarget = "darwin-arm64";
    };
    x86_64-darwin = {
      clipboardNativePackage = "clipboard-darwin-x64";
      clipboardNativeFile = "clipboard.darwin-x64.node";
      tuiNativeTarget = "darwin-x64";
    };
    aarch64-linux = {
      clipboardNativePackage = "clipboard-linux-arm64-${linuxClipboardAbi}";
      clipboardNativeFile = "clipboard.linux-arm64-${linuxClipboardAbi}.node";
      tuiNativeTarget = null;
    };
    x86_64-linux = {
      clipboardNativePackage = "clipboard-linux-x64-${linuxClipboardAbi}";
      clipboardNativeFile = "clipboard.linux-x64-${linuxClipboardAbi}.node";
      tuiNativeTarget = null;
    };
  };
  platform =
    platformsBySystem.${stdenv.hostPlatform.system}
      or (throw "Unsupported Pi platform: ${stdenv.hostPlatform.system}");

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
    cp -r node_modules/@mariozechner/${platform.clipboardNativePackage} "$pkgdir/node_modules/@mariozechner/"
    cp node_modules/@mariozechner/${platform.clipboardNativePackage}/${platform.clipboardNativeFile} \
      "$pkgdir/node_modules/@mariozechner/clipboard/"
    ${lib.optionalString (platform.tuiNativeTarget != null) ''
      mkdir -p "$pkgdir/native/darwin/prebuilds/${platform.tuiNativeTarget}"
      cp node_modules/@earendil-works/pi-tui/native/darwin/prebuilds/${platform.tuiNativeTarget}/darwin-modifiers.node \
        "$pkgdir/native/darwin/prebuilds/${platform.tuiNativeTarget}/"
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
    clipboardNative="$out/libexec/pi/node_modules/@mariozechner/clipboard/${platform.clipboardNativeFile}"
    test -f "$clipboardNative"
    ${bun}/bin/bun --eval '
      const { createRequire } = require("module");
      const { join } = require("path");
      const { pathToFileURL } = require("url");
      const requireFromExecutable = createRequire(pathToFileURL(join(process.argv[1], "package.json")).href);
      requireFromExecutable("@mariozechner/clipboard");
    ' "$out/libexec/pi"
  ''
  + lib.optionalString (platform.tuiNativeTarget != null) ''
    nativeModifiers="$out/libexec/pi/native/darwin/prebuilds/${platform.tuiNativeTarget}/darwin-modifiers.node"
    test -f "$nativeModifiers"
    ${bun}/bin/bun --eval 'require(process.argv[1])' "$nativeModifiers"
  '';

  passthru.category = "AI Coding Agents";

  meta = {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/earendil-works/pi";
    changelog = "https://github.com/earendil-works/pi/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ aos ];
    platforms = builtins.attrNames platformsBySystem;
    mainProgram = "pi";
  };
}
