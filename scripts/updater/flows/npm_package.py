"""Update flow for packages built from an npm registry tarball."""

from __future__ import annotations

import sys
from typing import TYPE_CHECKING

from updater.deps import update_dependency_hash
from updater.hash import DUMMY_SHA256_HASH, calculate_url_hash
from updater.hashes_file import load_hashes, save_hashes
from updater.npm import extract_or_generate_lockfile
from updater.version import fetch_npm_version, should_update

if TYPE_CHECKING:
    from pathlib import Path


def update_npm_package(
    pkg_dir: Path,
    npm_package: str,
    flake_attr: str,
    *,
    lockfile_env: dict[str, str] | None = None,
    strip_dev_dependencies: bool = False,
    require_lockfile: bool = True,
    fetchzip: bool = False,
) -> None:
    """Update a package built from an npm registry tarball.

    Bumps version and source hash in hashes.json, refreshes package-lock.json
    from the tarball, and recalculates npmDepsHash.

    Set ``fetchzip=True`` for packages whose derivation fetches the tarball
    with fetchzip instead of fetchurl: the source hash is then calculated over
    the unpacked tarball and stored under "hash" instead of "sourceHash".
    """
    hashes_file = pkg_dir / "hashes.json"
    data = load_hashes(hashes_file)
    current = data["version"]
    latest = fetch_npm_version(npm_package)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_name = npm_package.rsplit("/", 1)[-1]
    tarball_url = (
        f"https://registry.npmjs.org/{npm_package}/-/{tarball_name}-{latest}.tgz"
    )

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url, unpack=fetchzip)

    if not extract_or_generate_lockfile(
        tarball_url,
        pkg_dir / "package-lock.json",
        env=lockfile_env,
        strip_dev_dependencies=strip_dev_dependencies,
    ):
        if require_lockfile:
            sys.exit(1)
        print("Warning: Failed to generate lockfile, continuing anyway...")

    # Dummy npmDepsHash: update_dependency_hash builds the package and
    # replaces it with the hash reported by the failed build.
    source_hash_key = "hash" if fetchzip else "sourceHash"
    data = {
        "version": latest,
        source_hash_key: source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(hashes_file, data)

    print("Calculating npm dependencies hash...")
    update_dependency_hash(flake_attr, "npmDepsHash", hashes_file, data)

    print(f"Updated to {latest}")
