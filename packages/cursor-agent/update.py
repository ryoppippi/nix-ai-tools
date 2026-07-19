#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 --command python3

"""Update script for cursor-agent package."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from updater import fetch_version_from_text, update_platform_binaries

# Build id suffix can contain hyphens (e.g. 2026.06.15-18-00-12-6f5a2cf);
# match them and anchor on the trailing path separator.
VERSION_PATTERN = (
    r"downloads\.cursor\.com/lab/([0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f-]+)/"
)

update_platform_binaries(
    Path(__file__).parent,
    fetch_latest=lambda: fetch_version_from_text(
        "https://cursor.com/install", VERSION_PATTERN
    ),
    url_template="https://downloads.cursor.com/lab/{version}/{platform}/agent-cli-package.tar.gz",
    platforms={
        "x86_64-linux": "linux/x64",
        "aarch64-linux": "linux/arm64",
        "x86_64-darwin": "darwin/x64",
        "aarch64-darwin": "darwin/arm64",
    },
)
