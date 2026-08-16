# Repository Guidelines

## Project Structure & Module Organization

This repository is a Bazel registry. The root `bazel_registry.json` declares registry settings; published modules live under `modules/<module_name>/`.

Each module has a `metadata.json` listing homepage, repository, versions, and yanked versions. Each version directory, such as `modules/libffi_bzl/3.7.1/`, contains `source.json` plus registry files or an `overlay/` applied to the upstream archive.

## Build, Test, and Development Commands

- `./overlay_integrity.py <module>/<version>`: recalculates `source.json` overlay hashes after editing files under `overlay/`. Example: `./overlay_integrity.py libffi_bzl/3.7.1`.
- `./overlay_mirror.py [<module>/<version>]`: replaces symlinked registry files with concrete copies and rewrites any mirrored file that drifted from its `overlay/` reference. Run it after editing `overlay/MODULE.bazel`; with no arguments it covers every module version.
- `python3 -m json.tool modules/<module>/metadata.json >/dev/null`: validates JSON syntax for edited metadata files.
- `git status --short`: checks changed registry files before committing.
- `bazel build` / `bazel test`: run these only with user-approved escalated permissions when they need network access. OpenAI Codex's sandbox blocks Bazel network requests; do not try to work around that by adding unrelated flags such as `--batch` or experimental options.

There is no repository-wide build target here. Validate module overlays in a consuming Bazel workspace when changing BUILD, MODULE, or `.bzl` behavior.

## Coding Style & Naming Conventions

Use two-space indentation in JSON. In Bazel overlays, prefer lowercase target names, explicit `visibility`, and `.bzl` helpers with descriptive snake_case symbols. Python scripts should stay Python 3 compatible, use `pathlib`, and keep command-line behavior deterministic.

Avoid `.` and `..` in Bazel C/C++ include paths. In particular, do not use `includes = ["."]`: `includes` propagates the package directory as a system include path to reverse dependencies and should only be a compatibility escape hatch for legacy or third-party layouts. Prefer normal workspace- or package-relative includes with headers declared in `hdrs`. When adapting an upstream public header layout, use an exact `strip_include_prefix` and, when needed, `include_prefix`. Use `local_includes = ["."]` only when the search path genuinely must apply to the current target and cannot be represented with declared headers.

Current `rules_cc` does not propagate the producing target's transitive runfiles when `cc_import.shared_library` points to a DSO-producing target; track the upstream fix in `rules_cc#695`. If that DSO dynamically depends on another Bazel-built library, temporarily repeat the public runtime-library target in the `cc_import`'s `deps` and mark it with `TODO(rules_cc#695)`. This keeps the dependency in downstream runfiles, including when the DSO link action is restored from a remote cache. Apply the workaround only to actual dynamic dependencies: leaf libraries need no duplicate, and a `cc_binary` tool already carries the runtime closure of its normal `deps`. Do not add a wrapping `cc_library` solely to forward these runfiles.

Module names should match their registry identity, for example `libexpat_bzl` or `wayland_bzl`. Version directories must match the version strings listed in `metadata.json`.

Never commit a symlink under `modules/`. Bazel fetches registry files over plain HTTP, and raw.githubusercontent.com serves a symlink's target path as the file body instead of following it, so consumers download a `MODULE.bazel` whose entire content is a path and the build fails. When a file exists both in `overlay/` and next to it, the `overlay/` copy is the reference and the mirrored copy is a duplicate of it — edit the overlay, then run `./overlay_mirror.py`.

## Testing Guidelines

For JSON-only changes, validate syntax and schema fields. For overlay changes, run `./overlay_integrity.py` for each affected version, then test from a Bazel consumer using the relevant platform or toolchain. Keep generated hash updates with the overlay edit.

Before committing, run `./overlay_mirror.py` and confirm `find modules -type l` prints nothing.

## Agent-Specific Instructions

When working as an OpenAI Codex agent, ask the user to confirm escalation before running Bazel commands that fetch repositories, download toolchains, or otherwise need network access. The sandbox blocks those requests and there is no repository-level workaround. Do not add Bazel flags to mask the issue; rerun the same meaningful command with escalated permissions.

## Commit & Pull Request Guidelines

Recent commits use short, imperative, lower-case summaries such as `adds build support for libffi` and `remove rules_foreign_cc from registry`. Follow that style and keep each commit focused on one module or registry concern.

Pull requests should describe the affected module/version, explain why metadata or overlay behavior changed, and include validation performed. Link upstream releases or issues when adding or updating source archives.
