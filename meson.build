project('jcli', 'd', license: 'MIT')

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

jcli_srcs = [
    'source/jcli/package.d',
    'source/jcli/cli.d'
]

jcli_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_srcs,
    dependencies: [jcli_core_dep, jcli_intro_dep, jcli_resolve_dep, jcli_argb_dep, jcli_argp_dep, jcli_comp_dep, jcli_text_dep, jcli_help_dep, jcli_auto_dep]
)

jcli_test_exe = executable(
    'jcli_test_exe',
    'source/dummymain.d',
    dependencies: jcli_dep,
    d_unittest: true
    # d_args: ['-main']
)

test('jcli', jcli_test_exe)