project('jcli-text', license: 'MIT')

jcli_text_srcs = [
    'source/jcli/text/package.d',
    'source/jcli/text/buffer.d',
    'source/jcli/text/helptext.d',
    'source/jansi.d'
]

jcli_text_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_text_srcs,
)