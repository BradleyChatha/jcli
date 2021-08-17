project('jcli-helptext', license: 'MIT')

jcli_core_dep = subproject('core').get_variable('jcli_core_dep')
jcli_text_dep = subproject('text').get_variable('jcli_text_dep')
jcli_intro_dep = subproject('introspect').get_variable('jcli_intro_dep')

jcli_help_srcs = [
    'source/jcli/helptext/package.d',
    'source/jcli/helptext/helptext.d',
]

jcli_help_dep = declare_dependency(
    include_directories: include_directories('source/'),
    sources: jcli_help_srcs,
    dependencies: [jcli_core_dep, jcli_text_dep, jcli_intro_dep]
)