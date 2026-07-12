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

  # Run upstream's Bun entry point with Bun; keeps Node out of the closure
  # and adds aarch64-linux support.
  postInstall = ''
    rm -f "$out/bin/pi"

    makeWrapper ${lib.getExe bun} "$out/bin/pi" \
      --add-flags "${packageRoot}/dist/bun/cli.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR ${packageRoot} \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';

  # The npm install hook patches shebangs to Node; point them at Bun instead.
  postFixup = ''
    grep -rlE '^#!.*/node$' "$out/lib" | xargs -r sed -i '1s|.*|#!${lib.getExe bun}|'
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
