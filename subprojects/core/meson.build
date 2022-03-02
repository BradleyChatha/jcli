project('jcli-core', license: 'MIT')

jcli_core_srcs = [
    'source/jcli/core/package.d',
    'source/jcli/core/udas.d',
    'source/jcli/core/pattern.d',
    'source/jcli/core/result.d',
    'source/jcli/core/utils.d',
    'source/jcli/core/flags.d',
]

jcli_core_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_core_srcs
)