project('jcli-text', license: 'MIT')

jcli_text_srcs = [
    'source/jcli/text/package.d',
    'source/jcli/text/buffer.d',
    'source/jcli/text/helptext.d',
    'source/jcli/text/console.d',
    'source/jcli/text/common.d',
    'source/jcli/text/layout.d',
    'source/jcli/text/widgets/package.d',
    'source/jcli/text/widgets/border.d',
    'source/jcli/text/widgets/text.d',
    'source/jcli/text/widgets/shortcuts.d',
    'source/jansi.d'
]

jcli_text_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_text_srcs,
)