project('jcli-argparser', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')

jcli_argp_srcs = [
    'source/jcli/argparser/package.d',
    'source/jcli/argparser/tokenizer.d',
]

jcli_argp_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_argp_srcs,
    dependencies: jcli_core_dep
)