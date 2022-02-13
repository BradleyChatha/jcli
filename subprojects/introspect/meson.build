project('jcli-introspect', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')

jcli_intro_srcs = [
    'source/jcli/introspect/package.d',
    'source/jcli/introspect/data.d',
    'source/jcli/introspect/flags.d',
]

jcli_intro_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_intro_srcs,
    dependencies: jcli_core_dep
)