{
  lib,
  buildNpmPackage,
  bun,
  fetchurl,
  fd,
  ripgrep,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  packageRoot = "$out/lib/node_modules/@earendil-works/pi-coding-agent";

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

  # copy-binary-assets reads ../../node_modules and src/ paths from upstream's
  # monorepo layout; recreate it around the unpacked npm tarball.
  postUnpack = ''
    mkdir -p "$NIX_BUILD_TOP/monorepo/packages"
    mv "$NIX_BUILD_TOP/$sourceRoot" "$NIX_BUILD_TOP/monorepo/packages/coding-agent"
    ln -s packages/coding-agent/node_modules "$NIX_BUILD_TOP/monorepo/node_modules"
    sourceRoot=monorepo/packages/coding-agent
  '';

  # Compile a standalone binary like upstream's build:binary script. Running
  # dist/bun/cli.js directly with Bun breaks extension module aliasing (#6794).
  # Runs before npmInstallHook so the shx dev dependency is still installed.
  preInstall = ''
    # Upstream embeds the worker as ./src/utils/image-resize-worker.ts and
    # loads it by that path at runtime; the npm tarball only ships dist/.
    mkdir -p src/utils src/modes src/core
    echo 'import "../../dist/utils/image-resize-worker.js";' > src/utils/image-resize-worker.ts
    ln -s ../../dist/modes/interactive src/modes/interactive
    ln -s ../../dist/core/export-html src/core/export-html

    bun build --compile ./dist/bun/cli.js ./src/utils/image-resize-worker.ts --outfile dist/pi
    npm run copy-binary-assets
  '';

  postInstall = ''
    pkgdir=$out/libexec/pi

    # The binary embeds all modules; ship only upstream's binary dist layout.
    rm -rf "$out/lib" "$out/bin"
    mkdir -p "$out/bin" "$out/libexec"
    cp -r dist "$pkgdir"
    # Keep patchShebangs from pulling Node into the closure via dist scripts.
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

  passthru.category = "AI Coding Agents";

  meta = {
    description = "A terminal-based coding agent with multi-model support";
    homepage = "https://github.com/earendil-works/pi";
    changelog = "https://github.com/earendil-works/pi/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ aos ];
    platforms = bun.meta.platforms;
    mainProgram = "pi";
  };
}
