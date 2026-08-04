"""Flag helpers for C-library overlays."""

FlagInfo = provider(
    "The value of a build option.",
    fields = ["value"],
)

TemplateSubstitutionsInfo = provider(
    "Generated template substitutions.",
    fields = ["substitutions"],
)

def _flag_impl(ctx):
    return FlagInfo(value = ctx.build_setting_value)

_bool_flag = rule(
    implementation = _flag_impl,
    build_setting = config.bool(flag = True),
)

_int_flag = rule(
    implementation = _flag_impl,
    build_setting = config.int(flag = True),
)

def bool_flag(name, default, visibility = ["//visibility:public"]):
    _bool_flag(
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

def int_flag(name, default, visibility = ["//visibility:public"]):
    _int_flag(
        name = name,
        build_setting_default = default,
        visibility = visibility,
    )

def _expand_config_impl(ctx):
    substitutions = dict(ctx.attr.base_substitutions)
    if ctx.attr.config:
        substitutions |= ctx.attr.config[TemplateSubstitutionsInfo].substitutions
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = substitutions,
    )
    return DefaultInfo(files = depset([ctx.outputs.out]))

expand_config_template = rule(
    implementation = _expand_config_impl,
    attrs = {
        "base_substitutions": attr.string_dict(),
        "config": attr.label(providers = [TemplateSubstitutionsInfo]),
        "out": attr.output(mandatory = True),
        "template": attr.label(allow_single_file = True, mandatory = True),
    },
)
