"""Template helpers for Expat's configured headers."""

SubstitutionsInfo = provider(
    "Generated template substitutions.",
    fields = ["substitutions"],
)

def _expand_config_impl(ctx):
    substitutions = dict(ctx.attr.base_substitutions)
    if ctx.attr.config:
        substitutions |= ctx.attr.config[SubstitutionsInfo].substitutions
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
        "config": attr.label(providers = [SubstitutionsInfo]),
        "out": attr.output(mandatory = True),
        "template": attr.label(allow_single_file = True, mandatory = True),
    },
)
