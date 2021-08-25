project('jcli-autocomplete', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')
jcli_intro_dep = subproject('introspect').get_variable('jcli_intro_dep')
jcli_argp_dep = subproject('argparser').get_variable('jcli_argp_dep')

jcli_auto_srcs = [
    'source/jcli/autocomplete/package.d',
    'source/jcli/autocomplete/complete.d',
]

jcli_auto_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_auto_srcs,
    dependencies: [jcli_core_dep, jcli_intro_dep, jcli_argp_dep]
)