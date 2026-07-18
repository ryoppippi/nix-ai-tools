#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for vibe-kanban package.

vibe-kanban is the rare GitHub project where the release tag carries a
timestamp suffix (`v0.1.44-20260424091429`). nix-update can't parse
that, and the package layers a second prebuilt-zip asset on top of the
normal source + cargoHash + npmDepsHash for a baked-in react-virtuoso
licence key, so we drive the update through hashes.json by hand.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import (
    calculate_url_hash,
    fetch_json,
    load_hashes,
    save_hashes,
    should_update,
    update_dependency_hash,
)
from updater.hash import DUMMY_SHA256_HASH

HASHES_FILE = Path(__file__).parent / "hashes.json"
OWNER = "BloopAI"
REPO = "vibe-kanban"


def fetch_latest_tag() -> tuple[str, str]:
    """Return (tag, semver) of the latest release.

    Tags look like `v0.1.44-20260424091429`; strip the `v` and timestamp
    suffix to derive the semver used as `version`.
    """
    data = fetch_json(f"https://api.github.com/repos/{OWNER}/{REPO}/releases/latest")
    if not isinstance(data, dict):
        msg = f"Expected dict from GitHub API, got {type(data)}"
        raise TypeError(msg)
    tag: str = data["tag_name"]
    return tag, tag.lstrip("v").split("-", 1)[0]


def main() -> None:
    """Update vibe-kanban hashes to the latest BloopAI release."""
    data = load_hashes(HASHES_FILE)
    tag, latest = fetch_latest_tag()
    print(f"Current: {data['version']}, Latest: {latest} (tag {tag})")
    if not should_update(data["version"], latest):
        print("Already up to date")
        return

    src_url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/{tag}.tar.gz"
    zip_url = f"https://github.com/{OWNER}/{REPO}/releases/download/{tag}/vibe-kanban-{tag}.zip"

    new_data = {
        "version": latest,
        "tag": tag,
        "hash": calculate_url_hash(src_url, unpack=True),
        "cargoHash": DUMMY_SHA256_HASH,
        "npmDepsHash": DUMMY_SHA256_HASH,
        "releaseZipHash": calculate_url_hash(zip_url, unpack=False),
    }
    save_hashes(HASHES_FILE, new_data)

    # cargoHash and npmDepsHash both fall out of FOD build failures, so
    # trigger them sequentially.
    for key in ("cargoHash", "npmDepsHash"):
        update_dependency_hash(".#vibe-kanban", key, HASHES_FILE, new_data)

    print(f"Updated to {latest} (tag {tag})")


if __name__ == "__main__":
    main()
