"""Shared-library naming and CMake substitutions for Expat's overlay."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

SHARED_LIB_NAME = {
    "@platforms//os:macos": "libexpat.dylib",
    "@platforms//os:windows": "libexpat.dll",
    "//conditions:default": "libexpat.so",
}

SHARED_LIB_LINKOPTS = {
    ("@platforms//os:macos", "@platforms//os:windows"): [],
    "//conditions:default": ["-Wl,-soname,libexpat.so"],
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
    dtd = _flag(ctx, "dtd")
    ge = _flag(ctx, "ge")
    context_bytes = _flag(ctx, "context_bytes")

    if context_bytes < 0:
        fail("context_bytes must be >= 0")
    if dtd and not ge:
        fail("dtd requires ge; either enable ge or disable dtd.")

    defines = []
    _define_if(defines, attr_info, "XML_ATTR_INFO")
    _define_if(defines, large_size, "XML_LARGE_SIZE")
    _define_if(defines, dtd, "XML_DTD")
    defines.append("XML_GE=%d" % (1 if ge else 0))
    defines.append("XML_CONTEXT_BYTES=%d" % context_bytes)

    return [
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                defines = depset(defines),
            ),
        ),
    ]

expat_config = rule(
    implementation = _config_impl,
    attrs = {
        "_attr_info": attr.label(default = ":attr_info"),
        "_context_bytes": attr.label(default = ":context_bytes"),
        "_dtd": attr.label(default = ":dtd"),
        "_ge": attr.label(default = ":ge"),
        "_large_size": attr.label(default = ":large_size"),
    },
)
