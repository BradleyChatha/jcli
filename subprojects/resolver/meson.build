project('jcli-resolver', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')

jcli_resolve_srcs = [
    'source/jcli/resolver/package.d',
    'source/jcli/resolver/resolver.d',
]

jcli_resolve_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_resolve_srcs,
    dependencies: jcli_core_dep
)