#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3

"""Update script for openspecui package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    extract_or_generate_lockfile,
    fetch_npm_version,
    load_hashes,
    save_hashes,
    should_update,
    update_dependency_hash,
)
from updater.hash import DUMMY_SHA256_HASH

SCRIPT_DIR = Path(__file__).parent
HASHES_FILE = SCRIPT_DIR / "hashes.json"
NPM_PACKAGE = "openspecui"


def main() -> None:
    """Update the openspecui package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_npm_version(NPM_PACKAGE)

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    tarball_url = (
        f"https://registry.npmjs.org/{NPM_PACKAGE}/-/{NPM_PACKAGE}-{latest}.tgz"
    )

    print("Calculating source hash...")
    source_hash = calculate_url_hash(tarball_url)

    # openspecui is published from a workspace; its devDependencies use the
    # workspace:* protocol that npm cannot resolve here. package.nix strips
    # them via `del(.devDependencies)`, so do the same when generating the lock.
    if not extract_or_generate_lockfile(
        tarball_url,
        SCRIPT_DIR / "package-lock.json",
        strip_dev_dependencies=True,
    ):
        return

    # Update hashes.json
    data = {
        "version": latest,
        "sourceHash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    # Calculate npmDepsHash
    update_dependency_hash(".#openspecui", "npmDepsHash", HASHES_FILE, data)

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
