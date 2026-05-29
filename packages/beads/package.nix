{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  dolt,
  go-bin,
  icu,
  pkg-config,
  versionCheckHook,
}:

buildGoModule.override { go = go-bin; } rec {
  pname = "beads";
  version = "1.0.5";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-zX4rrZfFG7panBty1iE7bL2ZVazmvktFY5kYK8Xax1c=";
  };

  vendorHash = "sha256-7x8ZOWWM5S2Bvqv1SDZZw3w+fvZJldkzddcXZ0DehZU=";

  nativeBuildInputs = [
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    icu
  ];

  # go-icu-regex's cgo directives use raw -licui18n etc. with no
  # `#cgo pkg-config:` line, so pkg-config never runs. With go-bin (the
  # upstream prebuilt toolchain) on darwin the icu include dir does not
  # make it into the compiler invocation; pass it explicitly so the
  # build is independent of which cc cgo ends up resolving.
  env = {
    CGO_ENABLED = "1";
    CGO_CFLAGS = "-I${lib.getDev icu}/include";
    CGO_CXXFLAGS = "-I${lib.getDev icu}/include";
    CGO_LDFLAGS = "-L${lib.getLib icu}/lib";
  };

  subPackages = [ "cmd/bd" ];

  doCheck = false;

  postInstall = ''
    wrapProgram $out/bin/bd \
      --prefix PATH : ${lib.makeBinPath [ dolt ]}
  '';

  doInstallCheck = true;

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "Workflow & Project Management";

  meta = with lib; {
    description = "A distributed issue tracker designed for AI-supervised coding workflows";
    homepage = "https://github.com/steveyegge/beads";
    changelog = "https://github.com/steveyegge/beads/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ zimbatm ];
    mainProgram = "bd";
    platforms = platforms.unix;
  };
}
