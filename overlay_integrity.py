#!/usr/bin/env python3
"""Fill in the "overlay" integrity hashes in a module version's source.json.

  ./overlay_integrity.py libffi_bzl/3.7.1

Every file under modules/<module>/<version>/overlay/ is hashed and recorded.
"""

import base64
import hashlib
import json
import sys
from pathlib import Path

IGNORED = {"MODULE.bazel.lock", ".DS_Store"}


def registry_root():
    for start in (Path.cwd(), Path(__file__).resolve().parent):
        for directory in (start, *start.parents):
            if (directory / "bazel_registry.json").is_file():
                return directory
    sys.exit("not inside a Bazel registry (no bazel_registry.json found)")


def sri(data):
    return "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()


def find_version_dir(arg):
    """Resolve <module>/<version>, or a path to a version directory."""
    root = registry_root()
    for candidate in (Path(arg), root / "modules" / arg, root / arg):
        if (candidate / "source.json").is_file():
            return candidate
    sys.exit(f"no source.json for: {arg}")


def update_overlay(version_dir):
    source = version_dir / "source.json"
    overlay_dir = version_dir / "overlay"
    if not overlay_dir.is_dir():
        sys.exit(f"no overlay directory: {overlay_dir}")

    data = json.loads(source.read_text())
    data["overlay"] = {
        str(path.relative_to(overlay_dir)): sri(path.read_bytes())
        for path in sorted(overlay_dir.rglob("*"))
        if path.is_file() and path.name not in IGNORED
    }
    source.write_text(json.dumps(data, indent=2) + "\n")
    for name, digest in data["overlay"].items():
        print(f"{name}  {digest}")


def main(args):
    if not args:
        sys.exit(__doc__)
    for arg in args:
        update_overlay(find_version_dir(arg))


if __name__ == "__main__":
    main(sys.argv[1:])
