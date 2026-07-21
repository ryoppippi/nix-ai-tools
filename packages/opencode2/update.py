#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for the opencode2 package.

OpenCode 2 ships through npm's next channel as platform-specific native binary
packages (@opencode-ai/cli-{platform}).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_npm_version, update_platform_binaries

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_npm_version("@opencode-ai/cli", tag="next"),
    url_template="https://registry.npmjs.org/@opencode-ai/cli-{platform}/-/cli-{platform}-{version}.tgz",
    platforms={
        "x86_64-linux": "linux-x64",
        "aarch64-linux": "linux-arm64",
        "aarch64-darwin": "darwin-arm64",
    },
)
