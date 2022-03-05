project('jcli-matching', license: 'MIT')

jcli_core_proj      = subproject('core')
jcli_intro_proj     = subproject('introspect')
jcli_resolve_proj   = subproject('resolver')
jcli_argb_proj      = subproject('argbinder')
jcli_argp_proj      = subproject('argparser')
jcli_comp_proj      = subproject('commandparser')
jcli_text_proj      = subproject('text')
jcli_help_proj      = subproject('helptext')
jcli_auto_proj      = subproject('autocomplete')

jcli_core_dep       = jcli_core_proj.get_variable('jcli_core_dep')
jcli_intro_dep      = jcli_intro_proj.get_variable('jcli_intro_dep')
jcli_resolve_dep    = jcli_resolve_proj.get_variable('jcli_resolve_dep')
jcli_argb_dep       = jcli_argb_proj.get_variable('jcli_argb_dep')
jcli_argp_dep       = jcli_argp_proj.get_variable('jcli_argp_dep')
jcli_comp_dep       = jcli_comp_proj.get_variable('jcli_comp_dep')
jcli_text_dep       = jcli_text_proj.get_variable('jcli_text_dep')
jcli_help_dep       = jcli_help_proj.get_variable('jcli_help_dep')
jcli_auto_dep       = jcli_auto_proj.get_variable('jcli_auto_dep')

jcli_commandgraph_srcs = [
    'source/jcli/commandgraph/cli.d',
    'source/jcli/commandgraph/internal.d',
    'source/jcli/commandgraph/wrapper.d',
    'source/jcli/commandgraph/package.d',
    'source/jcli/commandgraph/graph.d',
]

jcli_commandgraph_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_commandgraph_srcs,
    dependencies: [jcli_core_dep, jcli_intro_dep, jcli_resolve_dep, jcli_argb_dep, jcli_argp_dep, jcli_comp_dep, jcli_text_dep, jcli_help_dep, jcli_auto_dep]
)