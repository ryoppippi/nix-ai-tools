{
  lib,
  stdenv,
  flake,
  python3,
  fetchFromGitHub,
  fetchPypi,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  # opentelemetry-exporter-otlp-proto-grpc 1.43.0 has timing-sensitive retry
  # tests that fail on the darwin builders with python 3.14; skip its test
  # suite there until nixpkgs sorts this out.
  python =
    if stdenv.hostPlatform.isDarwin then
      python3.override {
        self = python;
        packageOverrides = _final: prev: {
          opentelemetry-exporter-otlp-proto-grpc =
            prev.opentelemetry-exporter-otlp-proto-grpc.overridePythonAttrs
              (_: {
                doCheck = false;
                # opentelemetry-sdk only ends up in the closure via the test
                # env, so the runtime deps check must be skipped as well.
                dontCheckRuntimeDeps = true;
              });
        };
      }
    else
      python3;

  terminaltexteffects = python.pkgs.buildPythonPackage rec {
    pname = "terminaltexteffects";
    version = "0.14.2";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-ITyJnOS492Q9LQVorxROEnThHkST259bBDh70XwhdxQ=";
    };

    build-system = with python.pkgs; [
      hatchling
    ];

    pythonImportsCheck = [ "terminaltexteffects" ];

    meta = with lib; {
      description = "Terminal visual effects engine";
      homepage = "https://github.com/ChrisBuilds/terminaltexteffects";
      license = licenses.mit;
      sourceProvenance = with sourceTypes; [ fromSource ];
      platforms = platforms.all;
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "bernstein";
  version = "3.8.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "sipyourdrink-ltd";
    repo = "bernstein";
    tag = "v${version}";
    hash = "sha256-ybxhnRQ5B8FVNDvM0Z/psWEYs866Jm8usb/uECNU4bU=";
  };

  # Upstream sometimes tags a release without bumping the version in
  # pyproject.toml (e.g. v1.6.6 still says 1.6.5), which trips the
  # versionCheckHook. Align the metadata with the tag we are building.
  postPatch = ''
    sed -i -E 's/^version = ".*"/version = "${version}"/' pyproject.toml
    # Upstream excludes core sub-packages (config/, orchestration/, etc.)
    # from the wheel, but the lazy-import finder in core/__init__.py still
    # references them at runtime. Remove the exclude list.
    sed -i '/^exclude = \[/,/^\]/d' pyproject.toml
  '';

  build-system = with python.pkgs; [
    hatchling
  ];

  dependencies = with python.pkgs; [
    asn1crypto
    cbor2
    click
    cryptography
    defusedxml
    fastapi
    httpx
    keyring
    mcp
    openai
    opentelemetry-api
    opentelemetry-exporter-otlp
    opentelemetry-sdk
    pillow
    pluggy
    prometheus-client
    pydantic-settings
    pyfiglet
    python-dotenv
    python-frontmatter
    pyyaml
    reportlab
    rich
    setproctitle
    signxml
    terminaltexteffects
    textual
    uvicorn
    watchdog
    websockets
  ];

  pythonRelaxDeps = [
    "click"
    "cryptography"
    "idna"
    "mcp"
    "openai"
    "opentelemetry-api"
    "opentelemetry-exporter-otlp"
    "opentelemetry-sdk"
    "pillow"
    "pydantic-settings"
    "python-dotenv"
    "reportlab"
    "starlette"
  ];

  # bernstein re-invokes itself and uvicorn via ``sys.executable -m ...``
  # in subprocesses (server_launch.py, server_supervisor.py, adapters/*).
  # The Nix wrapper sets NIX_PYTHONPATH which is consumed and unset by
  # sitecustomize.py, so child interpreters lose access to the closure.
  # Export PYTHONPATH so subprocess spawns can resolve the runtime deps.
  makeWrapperArgs = [
    "--prefix"
    "PYTHONPATH"
    ":"
    "${placeholder "out"}/${python.sitePackages}:${python.pkgs.makePythonPath dependencies}"
  ];

  pythonImportsCheck = [ "bernstein" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "--version" ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "Multi-agent orchestrator for CLI coding agents — spawn, coordinate, and manage parallel AI agents";
    homepage = "https://github.com/sipyourdrink-ltd/bernstein";
    changelog = "https://github.com/sipyourdrink-ltd/bernstein/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ chernistry ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "bernstein";
  };
}
