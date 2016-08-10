def _impl(ctx):
  print("Rule name = %s, package = %s" % (ctx.label.name, ctx.label.package))

  includes = set(ctx.attr.includes)
  inputs = set(ctx.files.srcs + ctx.files.data + ctx.files.capnp_capnp + ctx.files.capnpc_cxx)
  for dep_target in ctx.attr.deps:
    includes += dep_target.capnp.includes
    inputs += dep_target.capnp.inputs

  out_path = ctx.var["GENDIR"]
  args = ["compile", "--verbose", "--no-standard-import", "-o" + ctx.executable.capnpc_cxx.path + ":" + out_path]
  include_flags = ["-I" + inc for inc in includes]

  ctx.action(
      inputs=list(inputs),
      outputs=ctx.outputs.outs,
      executable=ctx.executable.capnp,
      arguments = args + include_flags + [s.path for s in ctx.files.srcs],
      mnemonic="GenCapnp",
  )

  return struct(
      capnp=struct(
          includes = includes,
          inputs = inputs,
      )
  )

_capnp_gen = rule(
    attrs={
        "srcs": attr.label_list(allow_files=True),
        "deps": attr.label_list(providers = ["capnp"]),
        "data": attr.label_list(allow_files=True),
        "includes": attr.string_list(),
        "capnp": attr.label(executable=True, single_file=True, mandatory=True,
                            default=Label("//third_party/capnproto:capnp")),
        "capnpc_cxx": attr.label(executable=True, single_file=True,
                                 mandatory=True,
                                 default=Label("//third_party/capnproto:capnpc-c++")),
        "capnp_capnp": attr.label(default=Label("//third_party/capnproto:capnp-capnp")),
        "outs": attr.output_list(),
    },
    output_to_genfiles=True,
    implementation=_impl,
)

def cc_capnp_library(
        name,
        srcs=[],
        deps=[],
        data=[],
        include=None,
        capnp="//third_party/capnproto:capnp",
        capnpc_cxx="//third_party/capnproto:capnpc-c++",
        capnp_capnp="//third_party/capnproto:capnp-capnp",
        **kargs):
    """Bazel rule to create a C++ capnproto library from capnp source files
    """

    includes = []
    if include != None:
      includes = [include]

    outs = ([s + ".h" for s in srcs] +
            [s + ".c++" for s in srcs])

    _capnp_gen(
        name=name + "_gencapnp",
        srcs=srcs,
        deps=[s + "_gencapnp" for s in deps],
        data=data,
        includes=includes,
        capnp=capnp,
        capnpc_cxx=capnpc_cxx,
        outs=outs,
        visibility=["//visibility:public"],
    )
    cc_libs = ["//third_party/capnproto:capnp-lib"]
    native.cc_library(
        name=name,
        srcs=outs,
        deps=cc_libs + deps,
        includes=includes,
        **kargs)
