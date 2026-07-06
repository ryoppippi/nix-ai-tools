# ctranslate2 4.8.1 (NixOS/nixpkgs#538070) ships a fetchSubmodules hash that
# does not reproduce; the real hash of the v4.8.1 tree with submodules is the
# one below. The Python module receives the C library as ctranslate2-cpp =
# pkgs.ctranslate2 (passed inline, not a member of the python set), so the fix
# has to land on the top-level attribute. Consumers apply it via pkgs.extend to
# scope the rebuild instead of using a global overlay. Drop once the upstream
# fix reaches nixpkgs-unstable.
_final: prev: {
  ctranslate2 = prev.ctranslate2.overrideAttrs (old: {
    src = old.src.overrideAttrs (_: {
      outputHash = "sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=";
    });
  });
}
