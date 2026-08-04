"""
Preprocess libffi's MSVC assembly into MASM, the way msvcc.sh does.
"""

load("@rules_cc//cc:action_names.bzl", "C_COMPILE_ACTION_NAME")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_ATTRS", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _msvc_asm_impl(ctx):
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

    out = ctx.actions.declare_file(ctx.label.name + ".asm")
    args = ctx.actions.args()
    args.add("/nologo")

    # /EP drops the #line directives MASM chokes on, /P writes a file rather
    # than stdout, /TC is needed because .S means nothing to cl.
    args.add_all(["/EP", "/P", "/TC"])
    args.add(out, format = "/Fi%s")
    args.add_all(context.includes, format_each = "/I%s")
    args.add_all(context.quote_includes, format_each = "/I%s")
    args.add_all(context.system_includes, format_each = "/I%s")
    args.add_all(ctx.attr.defines, format_each = "/D%s")
    args.add(ctx.file.src)

    ctx.actions.run(
        executable = compiler,
        arguments = [args],
        inputs = depset(
            [ctx.file.src] + ctx.files.hdrs,
            transitive = [context.headers, cc_toolchain.all_files],
        ),
        outputs = [out],
        env = environment,
        mnemonic = "MsvcPreprocessAsm",
        progress_message = "Preprocessing %{input} into MASM",
    )
    return DefaultInfo(files = depset([out]))

msvc_asm = rule(
    implementation = _msvc_asm_impl,
    attrs = {
        "src": attr.label(allow_single_file = [".S"], mandatory = True),
        "hdrs": attr.label_list(allow_files = True, doc = "Headers `src` includes from its own directory."),
        "deps": attr.label_list(providers = [CcInfo]),
        "defines": attr.string_list(),
    } | CC_TOOLCHAIN_ATTRS,
    toolchains = use_cc_toolchain(),
    fragments = ["cpp"],
)
