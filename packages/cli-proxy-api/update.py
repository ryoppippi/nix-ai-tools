#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for cli-proxy-api package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_github_latest_release,
    load_hashes,
    save_hashes,
    should_update,
    update_dependency_hash,
)
from updater.hash import DUMMY_SHA256_HASH

HASHES_FILE = Path(__file__).parent / "hashes.json"


def main() -> None:
    """Update the cli-proxy-api package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release("router-for-me", "CLIProxyAPI")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url = f"https://github.com/router-for-me/CLIProxyAPI/archive/refs/tags/v{latest}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        "vendorHash": DUMMY_SHA256_HASH,
    }
    save_hashes(HASHES_FILE, data)

    update_dependency_hash(".#cli-proxy-api", "vendorHash", HASHES_FILE, data)

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
