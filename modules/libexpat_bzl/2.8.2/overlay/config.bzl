"""CMake configure substitutions for Expat's overlay."""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(
    "@bazel_skylib//rules:common_settings.bzl",
    "BuildSettingInfo",
    "bool_flag",
)
load(":templates.bzl", "SubstitutionsInfo")

_PACKAGE = "expat"
_SOVERSION = "1"
_SONAME = "libexpat.so.%s" % _SOVERSION

SHARED_LIB_NAME = {
    "@platforms//os:macos": "libexpat.%s.dylib" % _SOVERSION,
    "@platforms//os:windows": "libexpat.dll",
    "//conditions:default": _SONAME,
}

SHARED_LIB_LINKOPTS = {
    ("@platforms//os:macos", "@platforms//os:windows"): [],
    "//conditions:default": ["-Wl,-soname," + _SONAME],
}

def _string(value):
    return "\"%s\"" % value

def _components(version):
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

def _cmakedefine(key, value = "1"):
    if value == None:
        return "/* #undef %s */" % key
    return "#define %s %s" % (key, value)

def _cmake_macros(macros):
    result = {}
    for key, value in macros.items():
        result["#cmakedefine %s\n" % key] = _cmakedefine(key, value) + "\n"
        result["#cmakedefine %s @%s@\n" % (key, key)] = _cmakedefine(key, value) + "\n"
        result["#cmakedefine %s \"@%s@\"\n" % (key, key)] = _cmakedefine(key, value) + "\n"
        # expand_template may replace @FOO@ before this whole-line key.
        if value != None:
            result["#cmakedefine %s %s\n" % (key, value)] = _cmakedefine(key, value) + "\n"
    return result

def expat_bool_flag(name, default, visibility = ["//visibility:public"]):
    bool_flag(
        name = name,
        build_setting_default = default,
        visibility = visibility,
    )
    native.config_setting(
        name = name + "_enabled",
        flag_values = {name: "True"},
    )
    native.config_setting(
        name = name + "_disabled",
        flag_values = {name: "False"},
    )

def expat_base_substitutions(version):
    version_release = _release(version)
    return _cmake_macros({
        "BYTEORDER": "__BYTE_ORDER__",
        "HAVE_ARC4RANDOM": None,
        "HAVE_ARC4RANDOM_BUF": None,
        "HAVE_DLFCN_H": "1",
        "HAVE_FCNTL_H": "1",
        "HAVE_GETENTROPY": None,
        "HAVE_GETPAGESIZE": "1",
        "HAVE_GETRANDOM": None,
        "HAVE_INTTYPES_H": "1",
        "HAVE_MEMORY_H": "1",
        "HAVE_MMAP": "1",
        "HAVE_STDINT_H": "1",
        "HAVE_STDLIB_H": "1",
        "HAVE_STRINGS_H": "1",
        "HAVE_STRING_H": "1",
        "HAVE_SYSCALL_GETRANDOM": None,
        "HAVE_SYS_STAT_H": "1",
        "HAVE_SYS_TYPES_H": "1",
        "HAVE_UNISTD_H": "1",
        "PACKAGE_BUGREPORT": _string("expat-bugs@libexpat.org"),
        "PACKAGE_NAME": _string(_PACKAGE),
        "PACKAGE_STRING": _string("%s %s" % (_PACKAGE, version_release)),
        "PACKAGE_TARNAME": _string(_PACKAGE),
        "PACKAGE_VERSION": _string(version_release),
        "STDC_HEADERS": "1",
        "WORDS_BIGENDIAN": None,
        "XML_ATTR_INFO": None,
        "XML_DEV_URANDOM": "1",
        "XML_DTD": "1",
        "XML_NS": "1",
        "off_t": None,
    }) | {
        "@BYTEORDER@": "__BYTE_ORDER__",
        "@PACKAGE_BUGREPORT@": "expat-bugs@libexpat.org",
        "@PACKAGE_NAME@": _PACKAGE,
        "@PACKAGE_STRING@": "%s %s" % (_PACKAGE, version_release),
        "@PACKAGE_TARNAME@": _PACKAGE,
        "@PACKAGE_VERSION@": version_release,
        "@XML_CONTEXT_BYTES@": "@EXPAT_CONTEXT_BYTES@",
        "@XML_GE@": "@EXPAT_XML_GE@",
    }

EXPAT_CONFIG_BY_WINDOWS = {
    "@platforms//os:windows": _cmake_macros({
        "BYTEORDER": "1234",
        "HAVE_DLFCN_H": None,
        "HAVE_FCNTL_H": None,
        "HAVE_GETPAGESIZE": None,
        "HAVE_MMAP": None,
        "HAVE_STRINGS_H": None,
        "HAVE_SYS_STAT_H": None,
        "HAVE_SYS_TYPES_H": None,
        "HAVE_UNISTD_H": None,
        "XML_DEV_URANDOM": None,
    }) | {"@BYTEORDER@": "1234"},
    "//conditions:default": {},
}

EXPAT_DEF_BY_ATTR_INFO = {
    "//:attr_info_enabled": {"@_EXPAT_COMMENT_ATTR_INFO@": " "},
    "//conditions:default": {"@_EXPAT_COMMENT_ATTR_INFO@": ";"},
}

EXPAT_DEF_BY_DTD_OR_GE = {
    ("//:dtd_enabled", "//:ge_enabled"): {"@_EXPAT_COMMENT_DTD_OR_GE@": " "},
    "//conditions:default": {"@_EXPAT_COMMENT_DTD_OR_GE@": ";"},
}

def _define_if(defines, condition, define):
    if condition:
        defines.append(define)

def _flag(ctx, name):
    return getattr(ctx.attr, "_" + name)[BuildSettingInfo].value

def _config_impl(ctx):
    attr_info = _flag(ctx, "attr_info")
    large_size = _flag(ctx, "large_size")
    min_size = _flag(ctx, "min_size")
    dtd = _flag(ctx, "dtd")
    ge = _flag(ctx, "ge")
    ns = _flag(ctx, "ns")
    context_bytes = _flag(ctx, "context_bytes")

    if context_bytes < 0:
        fail("context_bytes must be >= 0")
    if dtd and not ge:
        fail("dtd requires ge; either enable ge or disable dtd.")

    public_defines = []
    _define_if(public_defines, attr_info, "XML_ATTR_INFO")
    _define_if(public_defines, large_size, "XML_LARGE_SIZE")
    _define_if(public_defines, dtd, "XML_DTD")
    public_defines.append("XML_GE=%d" % (1 if ge else 0))

    private_defines = []
    _define_if(private_defines, large_size, "XML_LARGE_SIZE")
    _define_if(private_defines, min_size, "XML_MIN_SIZE")

    substitutions = {"@EXPAT_CONTEXT_BYTES@": str(context_bytes)}
    substitutions["@EXPAT_XML_GE@"] = "1" if ge else "0"
    substitutions |= _cmake_macros({"XML_ATTR_INFO": "1" if attr_info else None})
    substitutions |= _cmake_macros({"XML_DTD": "1" if dtd else None})
    substitutions |= _cmake_macros({"XML_NS": "1" if ns else None})

    return [
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                defines = depset(public_defines),
                local_defines = depset(private_defines),
            ),
        ),
        SubstitutionsInfo(substitutions = substitutions),
    ]

expat_config = rule(
    implementation = _config_impl,
    attrs = {
        "_attr_info": attr.label(default = ":attr_info"),
        "_context_bytes": attr.label(default = ":context_bytes"),
        "_dtd": attr.label(default = ":dtd"),
        "_ge": attr.label(default = ":ge"),
        "_large_size": attr.label(default = ":large_size"),
        "_min_size": attr.label(default = ":min_size"),
        "_ns": attr.label(default = ":ns"),
    },
)
