"""Generates libffi's ELF symbol version script."""

load("@rules_cc//cc:action_names.bzl", "C_COMPILE_ACTION_NAME")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_ATTRS", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _version_script_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    compiler = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
    )
    environment = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = cc_common.create_compile_variables(
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
        ),
    )
    context = cc_common.merge_compilation_contexts(
        compilation_contexts = [dep[CcInfo].compilation_context for dep in ctx.attr.deps],
    )

    args = ctx.actions.args()
    args.add(ctx.attr.target, format = "-D%s")
    args.add("-DGENERATE_LIBFFI_MAP")
    args.add_all(["-E", "-x", "assembler-with-cpp"])
    args.add_all(context.includes, before_each = "-I")
    args.add_all(context.quote_includes, before_each = "-iquote")
    args.add_all(context.system_includes, before_each = "-isystem")
    args.add_all(["-o", ctx.outputs.out])
    args.add(ctx.file.src)

    ctx.actions.run(
        executable = compiler,
        arguments = [args],
        inputs = depset(
            [ctx.file.src],
            transitive = [context.headers, cc_toolchain.all_files],
        ),
        outputs = [ctx.outputs.out],
        env = environment,
        mnemonic = "LibffiVersionScript",
        progress_message = "Generating libffi ELF version script",
    )
    return DefaultInfo(files = depset([ctx.outputs.out]))

version_script = rule(
    implementation = _version_script_impl,
    attrs = {
        "deps": attr.label_list(providers = [CcInfo]),
        "out": attr.output(mandatory = True),
        "src": attr.label(allow_single_file = True, mandatory = True),
        "target": attr.string(mandatory = True),
    } | CC_TOOLCHAIN_ATTRS,
    toolchains = use_cc_toolchain(),
    fragments = ["cpp"],
)
