# Notes for hand-written C overlays

Written while porting libffi 3.7.1. Nothing here has been extracted yet; this is a
shortlist of what looks worth sharing once a second or third autotools project
(mimalloc, expat, libxml2, …) needs the same thing.

## Candidates for a shared module

**Platform config settings** — `modules/libffi_bzl/3.7.1/overlay/platforms/BUILD.bazel`.
The os × cpu `config_setting_group`s, plus the fact that 32-bit x86 and 32-bit ARM each
have two constraint values that mean one thing (`x86_32`/`i386`, `arm`/`armv7`), and that
`@platforms//cpu:arm64` is an alias of `aarch64`. Nothing in that file is libffi-specific
except which combinations it declares. Strongest candidate.

**Autoheader substitution** — `config.bzl`'s `_define` + `_macros`. Every autotools project
ships a `config.h.in` full of `#undef FOO` lines, and filling it in is the same three lines
of Starlark plus an `expand_template`. Comes with a trap worth carrying over: the
substitution key must include the trailing newline, or `#undef HAVE_LONG_DOUBLE` also
matches the start of `#undef HAVE_LONG_DOUBLE_VARIANT`.

**Version macros from the registry** — `config.bzl`'s `_components`/`_release`. Turning
`module_version()` into `PACKAGE_VERSION`, `VERSION` and a packed integer, tolerating both a
`.bcr.N` suffix and the `None` you get from an `*_override`. Identical for every module.

**Static/dynamic linkage** — the `linkage` flag and the `:objects` → `:shared` →
`:import_library` → `:dynamic` → `:libffi` chain in `BUILD.bazel`. The reason it exists is
not libffi-specific at all: on Windows the header decides `dllimport` vs `dllexport` vs
nothing at *compile* time, while Bazel picks linkage at *link* time, so one bit has to
arrive by flag. Every C library has the same pattern under a different macro name —
`XML_STATIC` (expat), `LIBXML_STATIC` (libxml2), `MI_SHARED_LIB` (mimalloc),
`FFI_STATIC_BUILD`/`FFI_BUILDING_DLL` here. A macro taking those two names as parameters
would cover all of them.

**Not shared**: `msvc_asm.bzl`. Only projects shipping MSVC assembly need `cl /EP` before
`ml64`, which is unusual — libffi has it, the others above do not.

## Techniques

- Layer a config header with `dict | select(...) | select(...)`. Later keys win, so a
  general cpu layer can be refined by narrower os and os+cpu layers instead of writing out
  the full cross product. `dict + select` is *not* supported — `unsupported binary
  operation: dict + select`.
- Constraint values work directly as select keys, so `@platforms//os:linux` needs no
  `config_setting` of its own. Only combinations do.
- `select(..., no_match_error = ...)` for anything platform-shaped, so an unsupported
  platform fails with a sentence instead of a fallback. `@platforms//:incompatible` in
  `srcs` is the other half, for targets rather than values.
- Keep private headers out of consumers' include paths with `implementation_deps`; it maps
  exactly onto automake's `noinst_HEADERS`.
- A source that is `#include`d rather than compiled (libffi's `src/dlmalloc.c`) belongs in
  `textual_hdrs`, never `srcs`.

## Gotchas

- **Editing an overlay needs `bazel shutdown`** in the consumer workspace, or Bazel keeps
  serving the previously extracted repo and you debug a file that is no longer there.
- Rerun `./overlay_integrity.py <module>/<version>` as the *last* step. A formatter touching
  a BUILD file after the hash is taken makes clients reject the overlay with a checksum
  mismatch.
- `module_version()` and `module_name()` are BUILD-file globals; in a `.bzl` they are
  `native.module_version()` and only callable during package loading.
- `cc_import` validates `interface_library` by file extension, so a versioned
  `libffi.so.8` is rejected. Gate that attribute to Windows with a `select` whose default is
  `None`.
- Bazel 9 removed the built-in `CcInfo`; load it from `@rules_cc//cc/common:cc_info.bzl`.
- `cc_shared_library` records no `SONAME` of its own — pass one via `user_link_flags` if the
  artifact is meant to be swappable or patchelf-able.

## Verification that paid off

Diffing the generated `config.h` against a real `./configure` run of the same tarball, per
platform. For libffi that produced byte-identical output on x86_64 and i386 and caught
every wrong assumption. Cheap to repeat for any autotools project.
