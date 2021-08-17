project('jcli-commandparser', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')
jcli_intro_dep = subproject('introspect').get_variable('jcli_intro_dep')
jcli_argp_dep = subproject('argparser').get_variable('jcli_argp_dep')
jcli_argb_dep = subproject('argbinder').get_variable('jcli_argb_dep')

jcli_comp_srcs = [
    'source/jcli/commandparser/package.d',
    'source/jcli/commandparser/parser.d',
]

jcli_comp_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_comp_srcs,
    dependencies: [jcli_core_dep, jcli_intro_dep, jcli_argp_dep, jcli_argb_dep]
)