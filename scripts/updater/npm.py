"""NPM package utilities for Nix package updates."""

import json
import os
import subprocess
import tarfile
import tempfile
from pathlib import Path
from typing import Any
from urllib.request import urlretrieve


def _can_prefetch_npm_lockfile(lockfile: Path) -> bool:
    """Return whether the lockfile has enough metadata for Nix prefetching."""
    data: dict[str, Any] = json.loads(lockfile.read_text())
    packages = data.get("packages", {})
    if not isinstance(packages, dict):
        return True

    for package_path, package_data in packages.items():
        if package_path == "" or not isinstance(package_data, dict):
            continue

        resolved = package_data.get("resolved")
        if not isinstance(resolved, str) or resolved.startswith("git+"):
            continue

        if "integrity" not in package_data:
            print(f"Skipping npm-shrinkwrap.json; missing integrity for {package_path}")
            return False

    return True


def extract_or_generate_lockfile(
    tarball_url: str,
    output_path: Path,
    *,
    env: dict[str, str] | None = None,
    strip_dev_dependencies: bool = False,
) -> bool:
    """Extract an npm lockfile from npm tarball or generate it.

    Downloads the npm tarball, checks if it contains package-lock.json or
    npm-shrinkwrap.json, and either extracts it or generates one using npm.

    Args:
        tarball_url: URL to the npm package tarball
        output_path: Path where package-lock.json should be written
        env: Optional environment variables to pass to npm install
        strip_dev_dependencies: Drop devDependencies from package.json before
            generating the lockfile. Needed for packages published from a
            workspace whose devDependencies use the ``workspace:*`` protocol,
            which npm cannot resolve outside the monorepo. Mirror this with a
            matching ``del(.devDependencies)`` in the package's derivation.

    Returns:
        True if lockfile was successfully extracted or generated, False otherwise

    """
    print("Extracting/generating package-lock.json from tarball...")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir_path = Path(tmpdir)
        tarball_path = tmpdir_path / "package.tgz"
        urlretrieve(tarball_url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir_path, filter="data")

        package_dir = tmpdir_path / "package"
        package_lock_src = package_dir / "package-lock.json"
        shrinkwrap_src = package_dir / "npm-shrinkwrap.json"

        # Check if lockfile exists in tarball
        if package_lock_src.exists():
            output_path.write_text(package_lock_src.read_text())
            print("Updated package-lock.json from tarball")
            return True

        # npm-shrinkwrap.json uses the same lockfile format and is published to
        # npm tarballs. Prefer it over regenerating a less exact lockfile when
        # it has enough metadata for Nix's npm dependency prefetcher.
        if shrinkwrap_src.exists() and _can_prefetch_npm_lockfile(shrinkwrap_src):
            output_path.write_text(shrinkwrap_src.read_text())
            print("Updated package-lock.json from npm-shrinkwrap.json in tarball")
            return True

        # Generate if not in tarball
        print("No npm lockfile in tarball, generating package-lock.json...")
        package_json = package_dir / "package.json"
        if not package_json.exists():
            print("ERROR: No package.json found!")
            return False

        if strip_dev_dependencies:
            manifest = json.loads(package_json.read_text())
            if manifest.pop("devDependencies", None) is not None:
                package_json.write_text(json.dumps(manifest, indent=2) + "\n")
                print("Stripped devDependencies before generating lockfile")

        run_env = {**os.environ, **(env or {})}

        # npm updates npm-shrinkwrap.json instead of creating package-lock.json
        # when shrinkwrap is present. Remove it when falling back to generation.
        if shrinkwrap_src.exists():
            shrinkwrap_src.unlink()

        subprocess.run(
            ["npm", "install", "--package-lock-only", "--ignore-scripts"],
            cwd=package_dir,
            env=run_env,
            check=True,
        )

        new_lock = package_dir / "package-lock.json"
        if new_lock.exists():
            output_path.write_text(new_lock.read_text())
            print("Generated package-lock.json")
            return True

        print("ERROR: Failed to generate package-lock.json")
        return False
