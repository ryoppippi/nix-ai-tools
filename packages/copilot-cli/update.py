#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for copilot-cli package.

Since 1.0.64 @github/copilot is a loader package; the actual binary ships in
per-platform packages (@github/copilot-<platform>), so update those hashes.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_npm_version, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_npm_version("@github/copilot"),
    url_template="https://registry.npmjs.org/@github/copilot-{platform}/-/copilot-{platform}-{version}.tgz",
    platforms={
        "x86_64-linux": "linux-x64",
        "aarch64-linux": "linux-arm64",
        "x86_64-darwin": "darwin-x64",
        "aarch64-darwin": "darwin-arm64",
    },
)
