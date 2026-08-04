"""Template helpers for Wayland's configured files."""

def _expand_template_impl(ctx):
    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = ctx.attr.substitutions,
    )
    return DefaultInfo(files = depset([ctx.outputs.out]))

expand_template = rule(
    implementation = _expand_template_impl,
    attrs = {
        "out": attr.output(mandatory = True),
        "substitutions": attr.string_dict(),
        "template": attr.label(allow_single_file = True, mandatory = True),
    },
)
