#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for agentsview package."""

import re
import sys
import urllib.request
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

# The pricing snapshot lives on a separate artifact branch, not in the tagged
# tree. The litellm-snapshot tool bakes in the ref/file it restores; read those
# constants from the tagged source so the embedded blob stays pinned.
SNAPSHOT_TOOL_PATH = "internal/pricing/cmd/litellm-snapshot/main.go"
SNAPSHOT_BASE_URL = "https://raw.githubusercontent.com/kenn-io/agentsview"


def resolve_snapshot(version: str) -> dict[str, str]:
    """Derive the pinned LiteLLM snapshot URL/hash from the tagged source."""
    tool_url = f"{SNAPSHOT_BASE_URL}/v{version}/{SNAPSHOT_TOOL_PATH}"
    with urllib.request.urlopen(tool_url) as response:
        source = response.read().decode()

    def const(name: str) -> str:
        match = re.search(rf'{name}\s*=\s*"([^"]+)"', source)
        if not match:
            msg = f"could not find {name} in {SNAPSHOT_TOOL_PATH}"
            raise ValueError(msg)
        return match.group(1)

    ref = const("defaultSnapshotRef")
    snapshot_file = const("defaultSnapshotFile")
    url = f"{SNAPSHOT_BASE_URL}/{ref}/{snapshot_file}"

    print("Calculating LiteLLM snapshot hash...")
    return {"url": url, "hash": calculate_url_hash(url)}


def main() -> None:
    """Update the agentsview package."""
    data = load_hashes(HASHES_FILE)
    current = data["version"]
    latest = fetch_github_latest_release("kenn-io", "agentsview")

    print(f"Current: {current}, Latest: {latest}")

    if not should_update(current, latest):
        print("Already up to date")
        return

    url = f"https://github.com/kenn-io/agentsview/archive/refs/tags/v{latest}.tar.gz"

    print("Calculating source hash...")
    source_hash = calculate_url_hash(url, unpack=True)

    data = {
        "version": latest,
        "hash": source_hash,
        "npmDepsHash": DUMMY_SHA256_HASH,
        "vendorHash": DUMMY_SHA256_HASH,
        "litellmSnapshot": resolve_snapshot(latest),
    }
    save_hashes(HASHES_FILE, data)

    update_dependency_hash(".#agentsview", "npmDepsHash", HASHES_FILE, data)

    update_dependency_hash(".#agentsview", "vendorHash", HASHES_FILE, data)

    print(f"Updated to {latest}")


if __name__ == "__main__":
    main()
