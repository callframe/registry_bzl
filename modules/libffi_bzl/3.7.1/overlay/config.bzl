"""The AC_SUBSTs and AC_DEFINEs of configure.ac, per platform.

The defaults are what ./configure gets from gcc and clang; the os layer
overrides them for MSVC. Later selects win over earlier ones.
"""

_PACKAGE = "libffi"
_SOVERSION = "8"
_SONAME = "libffi.so.%s" % _SOVERSION

SHARED_LIB_NAME = {
    "@platforms//os:macos": "libffi.%s.dylib" % _SOVERSION,
    "@platforms//os:windows": "libffi.dll",
    "//conditions:default": _SONAME,
}

# Bazel names the file but records no SONAME of its own.
SHARED_LIB_LINKOPTS = {
    ("@platforms//os:macos", "@platforms//os:windows"): [],
    "//conditions:default": ["-Wl,-soname," + _SONAME],
}

def _string(value):
    return "\"%s\"" % value

def _components(version):
    # None for an *_override. Like configure.ac, drop each component at its
    # first non-digit, so 3.7.1-rc0 and 3.7.1.bcr.1 both give (3, 7, 1).
    components = []
    for part in (version or "0.0.0").split(".")[:3]:
        digits = ""
        for char in part.elems():
            if not char.isdigit():
                break
            digits += char
        components.append(int(digits) if digits else 0)
    return components

def _release(version):
    return "%d.%d.%d" % tuple(_components(version))

def _packed(version):
    major, minor, micro = _components(version)
    return major * 10000 + minor * 100 + micro

def _define(key, value):
    if value == None:
        return "/* #undef %s */" % key
    return "#define %s %s" % (key, value)

def _macros(macros):
    # The trailing newline keeps "#undef HAVE_LONG_DOUBLE" from matching inside
    # "#undef HAVE_LONG_DOUBLE_VARIANT".
    return {
        "#undef %s\n" % key: _define(key, value) + "\n"
        for key, value in macros.items()
    }

# --- ffi.h -----------------------------------------------------------------

def ffi_h(version):
    return {
        "@VERSION@": _release(version),
        "@FFI_VERSION_STRING@": _release(version),
        "@FFI_VERSION_NUMBER@": str(_packed(version)),
    }

FFI_H_BY_CPU = {
    "@platforms_extended//cpu:x64": {
        "@TARGET@": "X86_64",
        "@HAVE_LONG_DOUBLE@": "1",
        "@FFI_EXEC_TRAMPOLINE_TABLE@": "0",
    },
    "//platforms:x86_32_not_macos": {
        "@TARGET@": "X86",
        "@HAVE_LONG_DOUBLE@": "1",
        "@FFI_EXEC_TRAMPOLINE_TABLE@": "0",
    },
    "@platforms_extended//cpu:arm64": {
        "@TARGET@": "AARCH64",
        "@HAVE_LONG_DOUBLE@": "1",
        "@FFI_EXEC_TRAMPOLINE_TABLE@": "0",
    },
    "//platforms:arm32_not_macos": {
        "@TARGET@": "ARM",
        # AAPCS: long double == double.
        "@HAVE_LONG_DOUBLE@": "0",
        "@FFI_EXEC_TRAMPOLINE_TABLE@": "0",
    },
}

FFI_H_X86_FREEBSD = {
    "//platforms:x86_freebsd": {"@TARGET@": "X86_FREEBSD"},
    "//conditions:default": {},
}

# The MS ABI has no extended precision type: long double == double.
FFI_H_BY_WINDOWS_CPU = {
    "@platforms_extended//platform:x64_windows": {
        "@TARGET@": "X86_WIN64",
        "@HAVE_LONG_DOUBLE@": "0",
    },
    "@platforms_extended//platform:x86_windows": {
        "@TARGET@": "X86_WIN32",
        "@HAVE_LONG_DOUBLE@": "0",
    },
    "@platforms_extended//platform:arm64_windows": {
        "@TARGET@": "ARM_WIN64",
        "@HAVE_LONG_DOUBLE@": "0",
    },
    "@platforms_extended//platform:arm32_windows": {
        "@TARGET@": "ARM_WIN32",
        "@HAVE_LONG_DOUBLE@": "0",
    },
    "//conditions:default": {},
}

# Apple's arm64 ABI, unlike AAPCS64.
FFI_H_MACOS_ARM64 = {
    "@platforms_extended//platform:arm64_macos": {
        "@HAVE_LONG_DOUBLE@": "0",
        "@FFI_EXEC_TRAMPOLINE_TABLE@": "1",
    },
    "//conditions:default": {},
}

# --- fficonfig.h -----------------------------------------------------------

def fficonfig(version):
    return _macros({
        "AC_APPLE_UNIVERSAL_BUILD": None,
        "EH_FRAME_FLAGS": _string("a"),
        "FFI_DEBUG": None,
        "FFI_EXEC_STATIC_TRAMP": None,
        "FFI_EXEC_TRAMPOLINE_TABLE": None,
        "FFI_MMAP_EXEC_EMUTRAMP_PAX": None,
        "FFI_MMAP_EXEC_WRIT": None,
        "FFI_NO_RAW_API": None,
        "FFI_NO_STRUCTS": None,
        "HAVE_ALLOCA_H": "1",
        "HAVE_ARM64E_PTRAUTH": None,
        "HAVE_AS_CFI_PSEUDO_OP": "1",
        "HAVE_AS_REGISTER_PSEUDO_OP": None,
        "HAVE_AS_S390_ZARCH": None,
        "HAVE_AS_SPARC_UA_PCREL": None,
        "HAVE_DLFCN_H": "1",
        "HAVE_HIDDEN_VISIBILITY_ATTRIBUTE": "1",
        "HAVE_INTTYPES_H": "1",
        "HAVE_LONG_DOUBLE_VARIANT": None,
        "HAVE_MEMCPY": "1",
        "HAVE_MEMFD_CREATE": None,
        "HAVE_RO_EH_FRAME": "1",
        "HAVE_STDINT_H": "1",
        "HAVE_STDIO_H": "1",
        "HAVE_STDLIB_H": "1",
        "HAVE_STRING_H": "1",
        "HAVE_STRINGS_H": "1",
        "HAVE_SYS_MEMFD_H": None,
        "HAVE_SYS_STAT_H": "1",
        "HAVE_SYS_TYPES_H": "1",
        "HAVE_UNISTD_H": "1",
        "LIBFFI_GNU_SYMBOL_VERSIONING": "1",
        "LT_OBJDIR": _string(".libs/"),
        "PACKAGE": _string(_PACKAGE),
        "PACKAGE_BUGREPORT": _string("http://github.com/libffi/libffi/issues"),
        "PACKAGE_NAME": _string(_PACKAGE),
        "PACKAGE_STRING": _string("%s %s" % (_PACKAGE, _release(version))),
        "PACKAGE_TARNAME": _string(_PACKAGE),
        "PACKAGE_URL": _string(""),
        "PACKAGE_VERSION": _string(_release(version)),
        "SIZEOF_DOUBLE": "8",
        "STDC_HEADERS": "1",
        "SYMBOL_UNDERSCORE": None,
        "USING_PURIFY": None,
        "VERSION": _string(_release(version)),
    })

FFICONFIG_BY_CPU = {
    "@platforms_extended//cpu:x64": _macros({
        "HAVE_AS_X86_64_UNWIND_SECTION_TYPE": "1",
        "HAVE_AS_X86_PCREL": "1",
        "HAVE_INT128": "1",
        "HAVE_LONG_DOUBLE": "1",
        "SIZEOF_LONG_DOUBLE": "16",
        "SIZEOF_SIZE_T": "8",
    }),
    "//platforms:x86_32_not_macos": _macros({
        "HAVE_AS_X86_64_UNWIND_SECTION_TYPE": None,
        "HAVE_AS_X86_PCREL": "1",
        "HAVE_INT128": None,
        "HAVE_LONG_DOUBLE": "1",
        # 80-bit x87, padded to the i386 ELF alignment.
        "SIZEOF_LONG_DOUBLE": "12",
        "SIZEOF_SIZE_T": "4",
    }),
    "@platforms_extended//cpu:arm64": _macros({
        "HAVE_AS_X86_64_UNWIND_SECTION_TYPE": None,
        "HAVE_AS_X86_PCREL": None,
        "HAVE_INT128": "1",
        "HAVE_LONG_DOUBLE": "1",
        "SIZEOF_LONG_DOUBLE": "16",
        "SIZEOF_SIZE_T": "8",
    }),
    "//platforms:arm32_not_macos": _macros({
        "HAVE_AS_X86_64_UNWIND_SECTION_TYPE": None,
        "HAVE_AS_X86_PCREL": None,
        "HAVE_INT128": None,
        "HAVE_LONG_DOUBLE": None,
        "SIZEOF_LONG_DOUBLE": "8",
        "SIZEOF_SIZE_T": "4",
    }),
}

FFICONFIG_BY_OS = {
    "@platforms//os:linux": _macros({
        "FFI_EXEC_STATIC_TRAMP": "1",
        "HAVE_MEMFD_CREATE": "1",
    }),
    "@platforms//os:macos": _macros({
        "FFI_MMAP_EXEC_WRIT": "1",
        # Mach-O has no @unwind section type and no version scripts.
        "HAVE_AS_X86_64_UNWIND_SECTION_TYPE": None,
        "LIBFFI_GNU_SYMBOL_VERSIONING": None,
        "SYMBOL_UNDERSCORE": "1",
    }),
    "@platforms//os:freebsd": _macros({
        "FFI_MMAP_EXEC_WRIT": "1",
        "HAVE_MEMFD_CREATE": "1",
        "HAVE_SYS_MEMFD_H": "1",
    }),
    "@platforms//os:openbsd": _macros({
        "FFI_MMAP_EXEC_WRIT": "1",
    }),
    "@platforms//os:netbsd": {},
    "@platforms//os:windows": _macros({
        "EH_FRAME_FLAGS": None,
        "HAVE_ALLOCA_H": None,
        "HAVE_AS_CFI_PSEUDO_OP": None,
        "HAVE_AS_X86_64_UNWIND_SECTION_TYPE": None,
        "HAVE_AS_X86_PCREL": None,
        "HAVE_DLFCN_H": None,
        "HAVE_HIDDEN_VISIBILITY_ATTRIBUTE": None,
        "HAVE_INT128": None,
        "HAVE_LONG_DOUBLE": None,
        "HAVE_RO_EH_FRAME": None,
        "HAVE_STRINGS_H": None,
        "HAVE_UNISTD_H": None,
        "LIBFFI_GNU_SYMBOL_VERSIONING": None,
        "SIZEOF_LONG_DOUBLE": "8",
    }),
}

# 32-bit COFF decorates symbols with an underscore.
FFICONFIG_WINDOWS_32BIT = {
    ("@platforms_extended//platform:x86_windows", "@platforms_extended//platform:arm32_windows"): _macros({
        "SYMBOL_UNDERSCORE": "1",
    }),
    "//conditions:default": {},
}

FFICONFIG_MACOS_ARM64 = {
    "@platforms_extended//platform:arm64_macos": _macros({
        "FFI_EXEC_TRAMPOLINE_TABLE": "1",
        "FFI_MMAP_EXEC_WRIT": None,
        "HAVE_LONG_DOUBLE": None,
        "SIZEOF_LONG_DOUBLE": "8",
    }),
    "//conditions:default": {},
}
