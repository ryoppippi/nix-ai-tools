{
  lib,
  flake,
  buildGoModule,
  buildNpmPackage,
  cacert,
  fetchFromGitHub,
  fetchurl,
  versionCheckHook,
  makeBinaryWrapper,
  unpinGoModVersionHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    hash
    npmDepsHash
    vendorHash
    litellmSnapshot
    ;

  src = fetchFromGitHub {
    owner = "kenn-io";
    repo = "agentsview";
    rev = "v${version}";
    inherit hash;
  };

  # The //go:embed pricing snapshot is not in the source tree; upstream
  # restores it from a pinned artifact commit over the network. Fetch that blob
  # directly. update.py keeps url/hash in sync from the tagged source.
  litellmSnapshotFile = fetchurl {
    inherit (litellmSnapshot) url hash;
  };

  frontend = buildNpmPackage {
    pname = "agentsview-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";
    inherit npmDepsHash;
    # @kenn-io/kit-ui is a git dependency with install scripts but no lockfile.
    forceGitDeps = true;
    makeCacheWritable = true;
    # vite-plus eagerly constructs a reqwest client on startup and panics
    # when SSL_CERT_FILE points at stdenv's /no-cert-file.crt sentinel.
    # Give it a real CA bundle so the client builds; the sandbox still
    # blocks any actual network egress.
    env.SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in

buildGoModule {
  pname = "agentsview";
  inherit version src vendorHash;

  nativeBuildInputs = [
    makeBinaryWrapper
    unpinGoModVersionHook
  ];

  subPackages = [ "cmd/agentsview" ];
  tags = [ "fts5" ];
  env.CGO_ENABLED = "1";

  preBuild = ''
    rm -rf internal/web/dist
    cp -r ${frontend} internal/web/dist

    install -Dm644 ${litellmSnapshotFile} internal/pricing/snapshot/litellm_snapshot.json.gz
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=v${version}"
    "-X main.buildDate=1970-01-01T00:00:00Z"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  postInstall = ''
    wrapProgram $out/bin/agentsview \
      --set AGENTSVIEW_TELEMETRY_ENABLED 0
  '';

  passthru.category = "Usage Analytics";

  meta = with lib; {
    description = "Local-first viewer and analytics for AI coding agent sessions";
    homepage = "https://github.com/kenn-io/agentsview";
    changelog = "https://github.com/kenn-io/agentsview/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ ak2k ];
    mainProgram = "agentsview";
    platforms = platforms.unix;
  };
}
