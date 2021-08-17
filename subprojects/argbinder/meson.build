project('jcli-argbinder', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')
jcli_intro_dep = subproject('introspect').get_variable('jcli_intro_dep')

jcli_argb_srcs = [
    'source/jcli/argbinder/package.d',
    'source/jcli/argbinder/binder.d',
]

jcli_argb_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_argb_srcs,
    dependencies: [jcli_core_dep, jcli_intro_dep]
)