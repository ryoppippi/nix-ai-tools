#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for herdr package.

On Linux herdr builds from source (Rust + zig for vendored libghostty-vt).
On Darwin we use upstream release binaries because zig's macOS SDK
discovery does not work in the Nix sandbox yet.  Updates therefore touch
the source hash, cargoHash, and the per-platform Darwin binary hashes.
"""

import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_platform_hashes,
    calculate_url_hash,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
    update_dependency_hash,
)
from updater.nix import run_command

HASHES_FILE = Path(__file__).parent / "hashes.json"
FLAKE_ROOT = Path(__file__).parent.parent.parent

# zon2nix-generated Zig dependency lockfile, vendored in-tree so package.nix
# can import it without import-from-derivation (disabled repo-wide).  Kept in
# sync with the pinned source on every version bump.
ZIG_DEPS_FILE = Path(__file__).parent / "build.zig.zon.nix"
ZIG_DEPS_PATH = "vendor/libghostty-vt/build.zig.zon.nix"

OWNER = "ogulcancelik"
REPO = "herdr"


def update_vendored_zig_deps(version: str) -> None:
    """Refresh the vendored build.zig.zon.nix from the pinned source tag."""
    url = f"https://raw.githubusercontent.com/{OWNER}/{REPO}/v{version}/{ZIG_DEPS_PATH}"
    print(f"Fetching {ZIG_DEPS_PATH} from v{version}")
    with urllib.request.urlopen(url) as response:
        ZIG_DEPS_FILE.write_bytes(response.read())
    # Upstream's zon2nix output is not nixfmt-clean; normalise so
    # formatter-check does not fail on the vendored file.
    run_command(["nix", "fmt", "--", str(ZIG_DEPS_FILE)], cwd=FLAKE_ROOT)


DARWIN_PLATFORMS = {
    "aarch64-darwin": "macos-aarch64",
    "x86_64-darwin": "macos-x86_64",
}


def main() -> None:
    """Update the herdr package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release(OWNER, REPO)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    print(f"Updating herdr from {current} to {latest}")

    src_url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/v{latest}.tar.gz"
    bin_url = (
        f"https://github.com/{OWNER}/{REPO}/releases/download/v{latest}/"
        "herdr-{platform}"
    )

    data["version"] = latest
    data["hash"] = calculate_url_hash(src_url, unpack=True)
    data["binaryHashes"] = calculate_platform_hashes(bin_url, DARWIN_PLATFORMS)
    save_hashes(HASHES_FILE, data)

    update_vendored_zig_deps(latest)

    update_dependency_hash(".#herdr", "cargoHash", HASHES_FILE, data)

    print(f"Updated herdr to {latest}")


if __name__ == "__main__":
    main()
