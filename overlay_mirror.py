#!/usr/bin/env python3
"""Keep the registry's mirrored module files concrete copies of their overlay original.

  ./overlay_mirror.py                    # every module version
  ./overlay_mirror.py libffi_bzl/3.7.1   # one version directory

Bazel downloads registry files over plain HTTP, and raw.githubusercontent.com serves
a symlink's target path as the file body instead of following it. Every served file
must therefore be a regular file. The copy under overlay/ is always the reference:
a symlink is replaced by the bytes it pointed at, and a mirrored file that differs
from its overlay counterpart is rewritten from the overlay.
"""

import os
import stat
import sys
from pathlib import Path

from overlay_integrity import IGNORED, find_version_dir, registry_root

# The only overlay file that is also served from the version directory itself:
# Bazel reads modules/<module>/<version>/MODULE.bazel to resolve the module.
MIRRORED = "MODULE.bazel"


def version_dirs(args, root):
    if args:
        return [find_version_dir(arg) for arg in args]
    return sorted(path.parent for path in (root / "modules").glob("*/*/source.json"))


def materialize(path, root):
    """Replace a symlink with a regular file holding the bytes it pointed at."""
    target = path.resolve()
    if not target.is_file():
        sys.exit(f"symlink does not point at a file: {path} -> {os.readlink(path)}")
    if root not in target.parents:
        sys.exit(f"symlink points outside the registry: {path} -> {target}")

    data = target.read_bytes()
    mode = stat.S_IMODE(target.stat().st_mode)
    path.unlink()
    path.write_bytes(data)
    path.chmod(mode)
    print(f"materialized {path.relative_to(root)}")


def sync_from_overlay(version_dir, root):
    """Rewrite mirrored files that drifted from their overlay reference."""
    overlay_dir = version_dir / "overlay"
    if not overlay_dir.is_dir():
        return

    for source in sorted(overlay_dir.iterdir()):
        if not source.is_file() or source.name in IGNORED:
            continue
        mirror = version_dir / source.name
        # MODULE.bazel is always mirrored; nothing else is served from the version
        # directory, so only refresh other files that someone already put there.
        if not mirror.is_file() and source.name != MIRRORED:
            continue
        data = source.read_bytes()
        if mirror.is_file() and mirror.read_bytes() == data:
            continue
        mirror.write_bytes(data)
        print(f"synced {mirror.relative_to(root)} from overlay")


def main(args):
    root = registry_root().resolve()
    for version_dir in version_dirs(args, root):
        for path in sorted(version_dir.rglob("*")):
            if path.is_symlink():
                materialize(path, root)
        sync_from_overlay(version_dir, root)


if __name__ == "__main__":
    main(sys.argv[1:])
